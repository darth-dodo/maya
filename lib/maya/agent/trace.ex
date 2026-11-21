defmodule Maya.Agent.Trace do
  @moduledoc """
  Numbers-only OpenTelemetry spans for the agent loop, exported to Langfuse (ADR-010): one turn
  span per Question, one per round (completion request) and one per tool call. Every attribute
  map is built here, from integers, atoms, the model id and known tool names only: never the
  Question, Answer, prompt, history, tool arguments or results, Progress, guest id or keys.
  Export runs in the SDK's batch processor, never on the turn path; with no Langfuse keys
  `config/runtime.exs` sets no exporter.
  """

  require OpenTelemetry.Tracer, as: Tracer

  alias Maya.Agent.Tools

  @tools Enum.map(Tools.definitions(), & &1.function.name)

  @doc "Runs `fun` (one Question) inside the turn span and tags its outcome."
  def turn(model, fun) do
    Tracer.with_span "turn", %{attributes: %{"gen_ai.request.model" => model}} do
      result = fun.()
      with {:error, reason} <- result, do: Tracer.set_attribute("maya.reason", reason(reason))
      result
    end
  end

  @doc "The turn tally on the turn span: rounds, history and token sums, the honesty outcome."
  def turn_numbers(turn) do
    Tracer.set_attributes(%{
      "maya.rounds" => turn.rounds,
      "maya.history" => turn.history,
      "maya.prompt_tokens" => turn.prompt_tokens,
      "maya.cached_tokens" => turn.cached_tokens,
      "maya.completion_tokens" => turn.completion_tokens,
      "maya.honesty" => turn.honesty
    })
  end

  @doc "Ends the open round span, if any, then starts round `n` under the turn span."
  def next_round(turn, n, model) do
    turn = end_round(turn)
    parent = Tracer.current_span_ctx()

    span =
      Tracer.start_span("round", %{
        attributes: %{"maya.round" => n, "gen_ai.request.model" => model}
      })

    Tracer.set_current_span(span)
    %{turn | span: {span, parent}}
  end

  @doc "Ends the open round span and makes the turn span current again."
  def end_round(%{span: {span, parent}} = turn) do
    OpenTelemetry.Span.end_span(span)
    Tracer.set_current_span(parent)
    %{turn | span: nil}
  end

  def end_round(turn), do: turn

  @doc "One reply's token counts on the current round span."
  def round_tokens(prompt, cached, completion) do
    Tracer.set_attributes(%{
      "gen_ai.usage.input_tokens" => prompt,
      "gen_ai.usage.output_tokens" => completion,
      "maya.cached_tokens" => cached
    })
  end

  @doc """
  Runs one tool call (`fun` returns `{content, progress, result}`) in a tool span with the tool
  name and a status atom. A name the model made up is `unknown`, so it cannot carry text.
  """
  def tool(name, fun) do
    Tracer.with_span "tool", %{attributes: %{"gen_ai.tool.name" => tool_name(name)}} do
      {content, progress, result} = fun.()
      Tracer.set_attribute("maya.tool.status", status(result))
      {content, progress}
    end
  end

  defp tool_name(name) when name in @tools, do: name
  defp tool_name(_made_up), do: "unknown"

  @doc "A tool result as one of `ok`, `not_found`, `past_horizon`, `refused`, `error`."
  def status({:ok, _fact}), do: :ok
  def status({:logged, _line, _progress}), do: :ok
  def status({:refused, _line}), do: :refused
  def status({:error, reason}) when reason in [:not_found, :past_horizon], do: reason
  def status(_other), do: :error

  @doc "An error reason as an atom: `timeout`, an atom reason, an HTTP status tag, else `error`."
  def reason(%Req.TransportError{reason: :timeout}), do: :timeout
  def reason({tag, _detail}) when is_atom(tag), do: tag
  def reason(tag) when is_atom(tag) and not is_nil(tag), do: tag
  def reason(_other), do: :error
end
