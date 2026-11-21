defmodule Maya.Agent.Answer do
  @moduledoc """
  The structured Answer (openspec/specs/agent, Structured Answer): the model's final reply is
  `{"answer": string, "used_tool_calls": [tool_call_id]}`, sent as a `response_format` JSON
  schema (https://openrouter.ai/docs/guides/features/structured-outputs) and checked here,
  since some providers treat the schema only as a hint. `check/3` is the honesty check
  (ADR-004): no write claim without a `log_event` or `set_setting` that confirmed, no talk about
  tools, no promise of a tool action that did not run this turn (#222). Cited ids are not
  checked: claims are checked against `ran` (#183). `spoken/1` keeps 2 to 3 spoken sentences.
  """
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key false
  embedded_schema do
    field :answer, :string
    field :used_tool_calls, {:array, :string}
  end

  @json_schema %{
    type: "object",
    # `answer` first, so a later streaming change can start TTS once that string closes.
    properties: %{
      answer: %{type: "string", description: "The words Maya says to the player."},
      used_tool_calls: %{
        type: "array",
        items: %{type: "string"},
        description: "The id of every tool call in this turn whose result the answer uses."
      }
    },
    required: ["answer", "used_tool_calls"],
    additionalProperties: false
  }

  @doc "The `response_format` sent on every agent request."
  def response_format,
    do: %{type: "json_schema", json_schema: %{name: "answer", strict: true, schema: @json_schema}}

  # A claim that something was written (an Event logged or refused, a Team, place or Dial
  # changed). Moved here from test/fixtures/spoiler_probes.json (#118). No "got it": the prompt
  # itself suggests it for a correction, and "Got it, Brawly uses Fighting types." is chat (#183).
  @claim_words [
    "refused",
    "logged",
    "added to your team",
    "I added",
    "I have added",
    "leads your team",
    "leads the team",
    "lead changed",
    "new lead",
    "your team is now",
    "team set",
    "set to",
    "is now level",
    "to the PC",
    "out of the PC",
    "deposited",
    "withdrawn",
    "withdrew",
    "undone",
    "off the record"
  ]

  # Everyday words, a claim only in a sentence with a Progress noun ("Your Team is updated"),
  # so "Noted, Brawly is tough." passes (#183).
  @change_words ["updated", "changed", "noted", "saved", "recorded"]
  @progress_nouns ["team", "badge", "badges", "PC", "box", "location", "humor", "dial", "dials"]

  # Maya never tells the Guest about her own machinery (#118, phone 2026-11-18).
  @tool_words ["tool", "tools", "function call", "tool call"]

  @write_tools ["log_event", "set_setting"]

  # A promise of a tool action instead of the call (#222, phone 2026-11-21): a sentence led by
  # the action ("Running the team check now.") or by "I'll", "I will", "I'm" or "let me" with a
  # look-up verb. A question is an offer ("Want me to run a team check?") and passes.
  # shortcut: English look-up verbs only, widen from real transcripts and Render log lines.
  # The gerund may follow a short lead-in ("Sure, running") and needs an object ("Running the",
  # "Looking up"), so "Looking at your Team, ...", "I'm looking forward" and "I'll check back"
  # stay chat.
  @promise ~r/(^([\w'’ ]{1,12}[,!] )?|\bi['’]?m )(running|checking|looking|searching|pulling|fetching) (up|for|a|the|your|it|that|this|now)\b|\b(i['’]?ll|i will|i['’]?m going to|let me) (run|check|look|search|pull|fetch|find)\b(?! back| forward)/iu

  def claim_words, do: @claim_words ++ @change_words
  def tool_words, do: @tool_words

  @doc "Parses the model's `content` into an Answer, or `{:error, :not_schema}`."
  def parse(content) when is_binary(content) do
    with {:ok, %{} = map} <- Jason.decode(content),
         %{valid?: true} = changeset <- changeset(map) do
      {:ok, apply_changes(changeset)}
    else
      _ -> {:error, :not_schema}
    end
  end

  def parse(_content), do: {:error, :not_schema}

  def changeset(params) do
    %__MODULE__{}
    |> cast(params, [:answer, :used_tool_calls])
    |> validate_required([:answer, :used_tool_calls])
    |> validate_length(:answer, min: 1)
  end

  @doc """
  The honesty check against `ran`, this turn's tool calls as `%{id => tool name}`, and the
  Guest's `question` (talk about tools is fine when the Guest asked about them). Checks the
  spoken text, so a claim trimmed away by `spoken/1` is never said and needs no correction.
  """
  def check(%__MODULE__{answer: text}, ran, question \\ "") do
    spoken = spoken(text)
    asked_tools? = Enum.any?(@tool_words, &said?(question, &1))

    cond do
      word = !asked_tools? && Enum.find(@tool_words, &said?(spoken, &1)) ->
        {:error, {:tool_talk, word}}

      word = unbacked_claim(spoken, ran) ->
        {:error, {:unbacked_claim, word}}

      promise = tool_promise(spoken, ran) ->
        {:error, promise}

      true ->
        {:ok, spoken}
    end
  end

  # A write claim is backed by a write that returned a confirm this turn, cited or not (#183):
  # the model often leaves `used_tool_calls` empty after log_event. In `ran` a confirmed write
  # is its tool name; a refused one is `{:refused, line}` and a failed one `{:failed, name}`,
  # which back nothing (#192). A refused line may still be said ("Every badge is already logged.").
  defp unbacked_claim(text, ran) do
    if not Enum.any?(Map.values(ran), &(&1 in @write_tools)) do
      refused = for {:refused, line} <- Map.values(ran), do: line
      text = Enum.reduce(refused, text, &String.replace(&2, &1, ""))
      Enum.find(@claim_words, &said?(text, &1)) || change_claim(text)
    end
  end

  # `{:tool_promise, tool}` when a sentence promises a tool action the turn did not run: the named
  # tool did not run, or no tool ran at all. A tool named in a promise sentence counts first, so
  # "Let me check: ... Want a team check too?" after gym_counter names nothing and passes; with
  # no tool run, a tool named anywhere ("... run the team check ... I'll run it now.") is the one.
  defp tool_promise(text, ran) do
    promises =
      text
      |> String.split(~r/(?<=[.!?])\s+/u)
      |> Enum.filter(&(not String.ends_with?(&1, "?") and Regex.match?(@promise, &1)))
      |> Enum.join(" ")

    ran_names = for name when is_binary(name) <- Map.values(ran), do: name

    cond do
      promises == "" -> nil
      named = read_tool_in(promises) -> if named not in ran_names, do: {:tool_promise, named}
      ran == %{} -> {:tool_promise, read_tool_in(text)}
      true -> nil
    end
  end

  # A read tool as the Guest hears it, "team_check" as "team check", to name it in the correction.
  defp read_tool_in(text) do
    Enum.find_value(Maya.Agent.Tools.definitions(), fn %{function: %{name: name}} ->
      (name not in @write_tools and said?(text, String.replace(name, "_", " "))) && name
    end)
  end

  defp change_claim(text) do
    text
    |> String.split(~r/(?<=[.!?])\s+/u)
    |> Enum.find_value(fn sentence ->
      Enum.any?(@progress_nouns, &said?(sentence, &1)) &&
        Enum.find(@change_words, &said?(sentence, &1))
    end)
  end

  @doc "Word boundaries and any letter case, so `noted` never matches `denoted`."
  def said?(text, phrase), do: Regex.match?(~r/\b#{Regex.escape(phrase)}\b/iu, text)

  @doc """
  At most 3 sentences (PRODUCT.md: 2 to 3 spoken sentences). Trimmed, not corrected: a cut
  costs no Answer time, while a corrective request would add a whole model round.
  """
  def spoken(text) do
    text
    |> String.trim()
    |> String.split(~r/(?<!\bMt\.)(?<!\bMr\.)(?<!\bSt\.)(?<=[.!?])\s+(?=\S)/u)
    |> Enum.take(3)
    |> Enum.join(" ")
  end

  @doc "The corrective user message for a rejected reply: why it was rejected."
  def correction(reason), do: "Your last reply was not said to the player: #{why(reason)}"

  defp why(:not_schema),
    do: "it was not the Answer JSON with a non-empty answer and used_tool_calls. Reply again."

  defp why({:tool_talk, _word}),
    do: "it mentioned tools. Never mention tools or calls; say the result plainly. Reply again."

  defp why({:tool_promise, nil}),
    do:
      "you said you would look something up, but made no tool call in this turn. Call the tool that answers " <>
        "the Question now, in this turn, then reply with its result. Never announce a call."

  defp why({:tool_promise, tool}),
    do:
      "you said you would run #{tool}, but did not call it in this turn. Call #{tool} now, in this turn, " <>
        "then reply with its result. Never announce a call."

  defp why({:unbacked_claim, word}),
    do:
      "you said \"#{word}\", but no log_event or set_setting confirmed a change in this turn. Call log_event, " <>
        "or reply again without claiming anything changed."
end
