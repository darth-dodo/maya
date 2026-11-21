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
  For `anthropic/` models every request also carries top-level `cache_control`, so the stable
  front (tools, system prompt, history) is read from cache; other providers cache on their own
  (https://openrouter.ai/docs/guides/best-practices/prompt-caching). Each Question ends with
  one info line of rounds, history turns and tokens, never content, and is one numbers-only
  trace of turn, round and tool spans (`Maya.Agent.Trace`, ADR-010).
  """

  require Logger

  alias Maya.Agent.{Answer, Prompt, Tools, Trace}
  alias Maya.GameData
  alias Maya.Voice.Turn

  @max_rounds 4
  @fallback "Not sure I got that right, ask me again?"
  @notes_down "I can't reach my notes right now, ask again soon?"
  @notes_down_error Jason.encode!(%{error: "notes_down"})
  @db_errors Maya.Repo.outage_errors()

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

    Trace.turn(model, fn ->
      with %{} = progress <- opts[:progress] || guest_progress(opts[:guest_id]),
           {:ok, req} <- client() do
        loop(
          {req, deadline},
          model,
          messages(Prompt.system(progress), turns, question),
          progress,
          1,
          %{
            ran: %{},
            corrected: false,
            question: question,
            confirms: [],
            history: min(length(turns), Turn.window()),
            rounds: 0,
            prompt_tokens: 0,
            cached_tokens: 0,
            completion_tokens: 0,
            honesty: :none,
            span: nil
          }
        )
      end
    end)
  end

  defp guest_progress(guest_id) when is_binary(guest_id), do: GameData.progress(guest_id)
  defp guest_progress(_none), do: {:error, :no_progress}

  @doc "The spoken line when Postgres cannot be reached (#82, #192)."
  def notes_down, do: @notes_down

  @doc "The system prompt, the last 25 turns as user and assistant messages, then the Question."
  def messages(system, turns, question) do
    history =
      for t <- Enum.take(turns, -Turn.window()),
          m <- [%{role: "user", content: t.question}, %{role: "assistant", content: t.answer}],
          do: m

    [%{role: "system", content: system}] ++ history ++ [%{role: "user", content: question}]
  end

  # `turn` holds this turn's tool calls (`ran`, see `ran_entry/1`), whether the one corrective
  # request was sent, the Question and the confirm lines of writes that ran. After the
  # correction, running out of requests or time gives the fallback line. A tool that cannot
  # reach Postgres ends the turn with the honest notes line, after any confirm (#192).
  defp loop(_client, _model, _messages, _progress, round, turn) when round > @max_rounds,
    do: give_up(turn, if(turn.corrected, do: {:ok, @fallback}, else: {:error, :round_cap}))

  defp loop({req, deadline} = client, model, messages, progress, round, turn) do
    left_ms = deadline - System.monotonic_time(:millisecond)
    turn = Trace.next_round(turn, round, model)
    {reply, turn} = tally(complete(req, left_ms, model, messages), turn)

    case reply do
      {:ok, %{"tool_calls" => [_ | _] = calls} = message} ->
        # A write changes Progress, so later calls, rounds and the system prompt see the new one.
        {results, new_progress} = Enum.map_reduce(calls, progress, &tool_message/2)
        ran = Map.merge(turn.ran, Map.new(Enum.zip(calls, results), &ran_entry/1))
        turn = %{turn | ran: ran, confirms: turn.confirms ++ confirms(results)}
        messages = if new_progress == progress, do: messages, else: system(messages, new_progress)

        if Enum.any?(results, &(&1.content == @notes_down_error)),
          do: done(turn, {:ok, Enum.join(turn.confirms ++ [@notes_down], " ")}),
          else:
            loop(client, model, messages ++ [message | results], new_progress, round + 1, turn)

      {:ok, %{"content" => text}} when is_binary(text) and text != "" ->
        with {:ok, answer} <- Answer.parse(text),
             {:ok, spoken} <- Answer.check(answer, turn.ran, turn.question) do
          done(%{turn | honesty: :ok}, {:ok, spoken})
        else
          {:error, reason} ->
            turn = %{turn | honesty: Trace.reason(reason)}
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

  defp system([%{role: "system"} | rest], progress),
    do: [%{role: "system", content: Prompt.system(progress)} | rest]

  # One `ran` entry from the tool result, never the Answer text (#192): a write backs a claim
  # only when it returned a confirm. Reads keep their name.
  defp ran_entry({call, %{content: content}}) do
    name = get_in(call, ["function", "name"])

    entry =
      case Jason.decode(content) do
        {:ok, %{"confirm" => _}} -> name
        {:ok, %{"refused" => line}} -> {:refused, line}
        {:ok, %{"error" => _}} -> {:failed, name}
        _fact -> name
      end

    {call["id"], entry}
  end

  defp confirms(results) do
    for %{content: content} <- results,
        {:ok, %{} = result} <- [Jason.decode(content)],
        line = result["confirm"] || result["refused"],
        do: line
  end

  # The fallback line or an error after a write ran would hide a real change (or refusal), so
  # the write's confirm or refused line is said instead. Only the outcome's tag is logged, never the Answer.
  defp give_up(%{confirms: []} = turn, outcome), do: done(turn, outcome)

  defp give_up(%{confirms: lines} = turn, outcome) do
    Logger.info("agent said the confirm line instead of: #{outcome_tag(outcome)}")
    done(turn, {:ok, Enum.join(lines, " ")})
  end

  # Sums one reply's `usage` (absent fields count as 0) into the turn and counts the round.
  defp tally({:ok, message, usage}, turn) do
    {prompt, cached, completion} =
      case usage do
        %{"prompt_tokens" => p} = u when is_integer(p) ->
          {p, cached_tokens(u["prompt_tokens_details"]), int(u["completion_tokens"])}

        _absent_or_odd ->
          {0, 0, 0}
      end

    Trace.round_tokens(prompt, cached, completion)

    {{:ok, message},
     %{
       turn
       | rounds: turn.rounds + 1,
         prompt_tokens: turn.prompt_tokens + prompt,
         cached_tokens: turn.cached_tokens + cached,
         completion_tokens: turn.completion_tokens + completion
     }}
  end

  defp tally(error, turn), do: {error, %{turn | rounds: turn.rounds + 1}}

  defp cached_tokens(%{"cached_tokens" => c}) when is_integer(c), do: c
  defp cached_tokens(_absent_or_odd), do: 0

  defp int(n) when is_integer(n), do: n
  defp int(_absent_or_odd), do: 0

  # The one turn log line: numbers only, never the Question, Answer or tool content.
  defp done(turn, outcome) do
    turn = Trace.end_round(turn)
    Trace.turn_numbers(turn)

    Logger.info(
      "agent turn rounds=#{turn.rounds} history=#{turn.history} " <>
        "prompt_tokens=#{turn.prompt_tokens} cached_tokens=#{turn.cached_tokens}"
    )

    outcome
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
  logged Event or a set Dial). Malformed arguments are a tool error, and so is a database
  outage (`notes_down`, #192): only the tool name and error kind are logged.
  """
  def tool_message(call, progress) do
    name = get_in(call, ["function", "name"])

    {content, progress} =
      Trace.tool(name, fn ->
        case decode(get_in(call, ["function", "arguments"])) do
          {:ok, args} -> run(name, args, progress)
          :error -> {Jason.encode!(%{error: "malformed_arguments"}), progress, :malformed}
        end
      end)

    {%{role: "tool", tool_call_id: call["id"], content: content}, progress}
  end

  defp run(name, args, progress) do
    result = Tools.call(name, args, progress)
    {Tools.encode(result, progress), after_call(result, progress), result}
  rescue
    e in @db_errors ->
      Logger.warning("tool #{name} failed: #{inspect(e.__struct__)}")
      {@notes_down_error, progress, :notes_down}
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
      json:
        Map.merge(cache_control(model), %{
          model: model,
          messages: messages,
          tools: Tools.definitions(),
          response_format: Answer.response_format(),
          provider: %{require_parameters: true}
        })
    )
    |> case do
      {:ok, %{status: 200, body: %{"choices" => [%{"message" => message} | _]} = body}} ->
        {:ok, message, body["usage"]}

      {:ok, %{status: 200}} ->
        {:ok, %{}, nil}

      {:ok, %{status: status}} ->
        {:error, {:http, status}}

      {:error, reason} ->
        {:error, reason}
    end
  end

  # Anthropic needs the field; OpenAI, Gemini and others cache on their own (OpenRouter docs).
  defp cache_control("anthropic/" <> _), do: %{cache_control: %{type: "ephemeral"}}
  defp cache_control(_model), do: %{}

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
