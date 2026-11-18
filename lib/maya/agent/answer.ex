defmodule Maya.Agent.Answer do
  @moduledoc """
  The structured Answer (openspec/specs/agent, Structured Answer): the model's final reply is
  `{"answer": string, "used_tool_calls": [tool_call_id]}`, sent as a `response_format` JSON
  schema (https://openrouter.ai/docs/guides/features/structured-outputs) and checked here,
  since some providers treat the schema only as a hint. `check/2` is the honesty check
  (ADR-004): no cited call that did not run, no write claim without `log_event` or
  `set_setting`, no talk about tools. `spoken/1` keeps 2 to 3 spoken sentences.
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
  # changed). Moved here from test/fixtures/spoiler_probes.json (#118).
  @claim_words [
    "refused",
    "logged",
    "recorded",
    "noted",
    "saved",
    "updated",
    "changed",
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
    "off the record",
    "got it"
  ]

  # Maya never tells the Guest about her own machinery (#118, phone 2026-11-18).
  @tool_words ["tool", "tools", "function call", "tool call"]

  @write_tools ["log_event", "set_setting"]

  def claim_words, do: @claim_words
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
  The honesty check against `ran`, this turn's tool calls as `%{id => tool name}`. Checks the
  spoken text, so a claim trimmed away by `spoken/1` is never said and needs no correction.
  """
  def check(%__MODULE__{answer: text, used_tool_calls: ids}, ran) do
    spoken = spoken(text)

    cond do
      id = Enum.find(ids, &(not Map.has_key?(ran, &1))) -> {:error, {:unknown_call, id}}
      word = Enum.find(@tool_words, &said?(spoken, &1)) -> {:error, {:tool_talk, word}}
      word = unbacked_claim(spoken, ids, ran) -> {:error, {:unbacked_claim, word}}
      true -> {:ok, spoken}
    end
  end

  defp unbacked_claim(text, ids, ran) do
    if not Enum.any?(ids, &(ran[&1] in @write_tools)),
      do: Enum.find(@claim_words, &said?(text, &1))
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

  defp why({:unknown_call, id}),
    do: "you cited #{id}, which did not run in this turn. Reply again citing only calls that ran."

  defp why({:tool_talk, _word}),
    do: "it mentioned tools. Never mention tools or calls; say the result plainly. Reply again."

  defp why({:unbacked_claim, word}),
    do:
      "you said \"#{word}\", but no log_event or set_setting ran in this turn. Call log_event, " <>
        "or reply again without claiming anything changed."
end
