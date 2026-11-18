defmodule Maya.Agent do
  @moduledoc """
  The hand-written agent loop (ARCHITECTURE.md 3) over OpenRouter chat completions
  (https://openrouter.ai/docs/guides/features/tool-calling). Every request carries `tools`, the
  structured Answer `response_format` and `provider.require_parameters`, so OpenRouter routes
  only to endpoints that honour both (https://openrouter.ai/docs/guides/routing/provider-selection).
  Each `tool_calls[].function.arguments` is a JSON string parsed per call, and each call gets
  one `role: "tool"` message with its `tool_call_id`. The final reply must pass
  `Maya.Agent.Answer.check/3`; a rejected one gets one corrective request, then the fallback
  line. At most 4 requests per Question. A write that ran is never silent: when the turn
  would end in the fallback line or an error, its confirm line is said instead (#183).
  """

  require Logger

  alias Maya.Agent.{Answer, Prompt, Tools}
  alias Maya.GameData

  @max_rounds 4
  @history 5
  @fallback "Not sure I got that right, ask me again?"

  @doc """
  Answers one Question for the guest in `opts[:guest_id]`, against that guest's Progress
  (ADR-008), or `opts[:progress]` when the caller already read it (the Conversation does, for
  STT). Without either there is no Progress, so it returns `{:error, :no_progress}`.
  `opts[:model]` overrides the configured model.
  """
  @spec answer(String.t(), [map()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def answer(question, turns, opts) do
    model = opts[:model] || voice(:agent_model)

    # One budget for the whole stage, so 4 slow rounds cannot leave the player in silence.
    deadline = System.monotonic_time(:millisecond) + voice(:agent_timeout_ms)

    with %{} = progress <- opts[:progress] || guest_progress(opts[:guest_id]),
         {:ok, req} <- client() do
      loop(
        {req, deadline},
        model,
        messages(Prompt.system(progress), turns, question),
        progress,
        1,
        %{ran: %{}, corrected: false, question: question, confirms: []}
      )
    end
  end

  defp guest_progress(guest_id) when is_binary(guest_id), do: GameData.progress(guest_id)
  defp guest_progress(_none), do: {:error, :no_progress}

  @doc "The system prompt, the last 5 turns as user and assistant messages, then the Question."
  def messages(system, turns, question) do
    history =
      for t <- Enum.take(turns, -@history),
          m <- [%{role: "user", content: t.question}, %{role: "assistant", content: t.answer}],
          do: m

    [%{role: "system", content: system}] ++ history ++ [%{role: "user", content: question}]
  end

  # `turn` holds this turn's tool calls (`ran`, id => name), whether the one corrective request
  # was sent, the Question and the confirm lines of writes that ran. After the correction,
  # running out of requests or time gives the fallback line.
  defp loop(_client, _model, _messages, _progress, round, turn) when round > @max_rounds,
    do: give_up(turn, if(turn.corrected, do: {:ok, @fallback}, else: {:error, :round_cap}))

  defp loop({req, deadline} = client, model, messages, progress, round, turn) do
    case complete(req, deadline - System.monotonic_time(:millisecond), model, messages) do
      {:ok, %{"tool_calls" => [_ | _] = calls} = message} ->
        # A logged Event changes Progress, so later calls and rounds see the new Progress.
        {results, progress} = Enum.map_reduce(calls, progress, &tool_message/2)
        ran = Map.merge(turn.ran, Map.new(calls, &{&1["id"], get_in(&1, ["function", "name"])}))
        turn = %{turn | ran: ran, confirms: turn.confirms ++ confirms(results)}
        loop(client, model, messages ++ [message | results], progress, round + 1, turn)

      {:ok, %{"content" => text}} when is_binary(text) and text != "" ->
        with {:ok, answer} <- Answer.parse(text),
             {:ok, spoken} <- Answer.check(answer, turn.ran, turn.question) do
          {:ok, spoken}
        else
          {:error, reason} ->
            rejected(reason, text, {client, model, messages, progress, round}, turn)
        end

      _empty_or_error when turn.corrected ->
        give_up(turn, {:ok, @fallback})

      {:ok, _empty} ->
        give_up(turn, {:error, :bad_reply})

      {:error, reason} ->
        give_up(turn, {:error, reason})
    end
  end

  defp confirms(results) do
    for %{content: content} <- results,
        %{"confirm" => line} <- [Jason.decode!(content)],
        do: line
  end

  # The fallback line or an error after a write ran would hide a real change, so the write's
  # confirm line is said instead. Only the outcome's tag is logged, never the Answer.
  defp give_up(%{confirms: []}, outcome), do: outcome

  defp give_up(%{confirms: lines}, outcome) do
    Logger.info("agent said the confirm line instead of: #{outcome_tag(outcome)}")
    {:ok, Enum.join(lines, " ")}
  end

  defp outcome_tag({:ok, _fallback}), do: :fallback
  defp outcome_tag({:error, reason}), do: reason_tag(reason)

  # A rejected Answer is never said: one corrective request naming the reason, then the fallback.
  # Only the reason's name is logged, never the Answer.
  defp rejected(reason, _text, _state, %{corrected: true} = turn) do
    Logger.info("agent fallback after correction: #{reason_tag(reason)}")
    give_up(turn, {:ok, @fallback})
  end

  defp rejected(reason, text, {client, model, messages, progress, round}, turn) do
    Logger.info("agent corrective request: #{reason_tag(reason)}")

    correction = [
      %{role: "assistant", content: text},
      %{role: "user", content: Answer.correction(reason)}
    ]

    loop(client, model, messages ++ correction, progress, round + 1, %{turn | corrected: true})
  end

  defp reason_tag({tag, _detail}), do: tag
  defp reason_tag(tag), do: tag

  @doc """
  One tool call as its `role: \"tool\"` reply and the Progress after it (changed only by a
  logged Event). Malformed arguments are a tool error.
  """
  def tool_message(call, progress) do
    {content, progress} =
      case decode(get_in(call, ["function", "arguments"])) do
        {:ok, args} ->
          result = Tools.call(get_in(call, ["function", "name"]), args, progress)
          {Tools.encode(result, progress), after_call(result, progress)}

        :error ->
          {Jason.encode!(%{error: "malformed_arguments"}), progress}
      end

    {%{role: "tool", tool_call_id: call["id"], content: content}, progress}
  end

  defp after_call({:logged, _line, new_progress}, _progress), do: new_progress
  defp after_call(_result, progress), do: progress

  defp decode(json) when is_binary(json) do
    case Jason.decode(json) do
      {:ok, %{} = args} -> {:ok, args}
      _ -> :error
    end
  end

  defp decode(_), do: :error

  defp complete(_req, left_ms, _model, _messages) when left_ms <= 0, do: {:error, :timeout}

  defp complete(req, left_ms, model, messages) do
    req
    |> Req.post(
      receive_timeout: left_ms,
      url: "/v1/chat/completions",
      json: %{
        model: model,
        messages: messages,
        tools: Tools.definitions(),
        response_format: Answer.response_format(),
        provider: %{require_parameters: true}
      }
    )
    |> case do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => message} | _]}}} -> {:ok, message}
      {:ok, %{status: 200}} -> {:ok, %{}}
      {:ok, %{status: status}} -> {:error, {:http, status}}
      {:error, reason} -> {:error, reason}
    end
  end

  defp client do
    config = Application.fetch_env!(:maya, :openrouter)

    case config[:api_key] do
      key when is_binary(key) and key != "" ->
        {:ok,
         Req.new(
           [
             base_url: config[:base_url],
             auth: {:bearer, key},
             # A retry costs more Answer time than the spoken error line saves.
             retry: false
           ] ++ config[:req_options]
         )}

      _ ->
        {:error, :no_api_key}
    end
  end

  defp voice(key), do: Application.fetch_env!(:maya, :voice)[key]
end
