defmodule Maya.Agent do
  @moduledoc """
  The hand-written agent loop (ARCHITECTURE.md 3) over OpenRouter chat completions
  (https://openrouter.ai/docs/guides/features/tool-calling). Every request carries `tools`;
  each `tool_calls[].function.arguments` is a JSON string parsed per call, and each call gets
  one `role: "tool"` message with its `tool_call_id`. At most 4 requests per Question.
  """

  alias Maya.Agent.{Prompt, Tools}
  alias Maya.GameData

  @max_rounds 4
  @history 5

  @doc """
  Answers one Question for the guest in `opts[:guest_id]`, against that guest's Progress
  (ADR-008). Without a guest there is no Progress, so it returns `{:error, :no_progress}`.
  `opts[:model]` overrides the configured model.
  """
  @spec answer(String.t(), [map()], keyword()) :: {:ok, String.t()} | {:error, term()}
  def answer(question, turns, opts) do
    model = opts[:model] || voice(:agent_model)

    # One budget for the whole stage, so 4 slow rounds cannot leave the player in silence.
    deadline = System.monotonic_time(:millisecond) + voice(:agent_timeout_ms)

    with %{} = progress <- guest_progress(opts[:guest_id]),
         {:ok, req} <- client() do
      loop(
        {req, deadline},
        model,
        messages(Prompt.system(progress), turns, question),
        progress,
        1
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

  defp loop(_req, _model, _messages, _progress, round) when round > @max_rounds,
    do: {:error, :round_cap}

  defp loop({req, deadline} = client, model, messages, progress, round) do
    case complete(req, deadline - System.monotonic_time(:millisecond), model, messages) do
      {:ok, %{"tool_calls" => [_ | _] = calls} = message} ->
        results = Enum.map(calls, &tool_message(&1, progress))
        loop(client, model, messages ++ [message | results], progress, round + 1)

      {:ok, %{"content" => text}} when is_binary(text) and text != "" ->
        {:ok, String.trim(text)}

      {:ok, _empty} ->
        {:error, :bad_reply}

      {:error, reason} ->
        {:error, reason}
    end
  end

  @doc "One tool call as its `role: \"tool\"` reply. Malformed arguments are a tool error."
  def tool_message(call, progress) do
    content =
      case decode(get_in(call, ["function", "arguments"])) do
        {:ok, args} ->
          get_in(call, ["function", "name"])
          |> Tools.call(args, progress)
          |> Tools.encode(progress)

        :error ->
          Jason.encode!(%{error: "malformed_arguments"})
      end

    %{role: "tool", tool_call_id: call["id"], content: content}
  end

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
      json: %{model: model, messages: messages, tools: Tools.definitions()}
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
