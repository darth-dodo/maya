defmodule Maya.Agent.Answer do
  @moduledoc """
  The structured Answer (openspec/specs/agent, Structured Answer): the model's final reply is
  `{"answer": string, "used_tool_calls": [tool_call_id]}`, sent as a `response_format` JSON
  schema (https://openrouter.ai/docs/guides/features/structured-outputs) and checked here,
  since some providers treat the schema only as a hint. `check/3` is the honesty check
  (ADR-004): no write claim without a `log_event` or `set_setting` that ran, no talk about
  tools. Cited ids are not checked: claims are checked against `ran` (#183). `spoken/1` keeps 2 to 3 spoken sentences.
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
    "is set to",
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
  @progress_nouns ["team", "badge", "badges", "PC", "box", "location"]

  # Maya never tells the Guest about her own machinery (#118, phone 2026-11-18).
  @tool_words ["tool", "tools", "function call", "tool call"]

  @write_tools ["log_event", "set_setting"]

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

      true ->
        {:ok, spoken}
    end
  end

  # A write claim is backed by any write that ran this turn, cited or not (#183): the model
  # often leaves `used_tool_calls` empty after log_event, and the write really happened.
  defp unbacked_claim(text, ran) do
    if not Enum.any?(Map.values(ran), &(&1 in @write_tools)),
      do: Enum.find(@claim_words, &said?(text, &1)) || change_claim(text)
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

  defp why({:unbacked_claim, word}),
    do:
      "you said \"#{word}\", but no log_event or set_setting ran in this turn. Call log_event, " <>
        "or reply again without claiming anything changed."
end
