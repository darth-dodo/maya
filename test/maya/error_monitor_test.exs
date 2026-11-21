defmodule Maya.ErrorMonitorTest do
  # Not async: the Conversation and its Tasks run outside the test process (shared sandbox and stubs).
  use Maya.DataCase, async: false

  import ExUnit.CaptureLog
  import Phoenix.ConnTest
  import Plug.Conn

  require Logger

  alias Maya.Conversation

  # Scenarios from openspec/changes/error-monitoring/specs/error-monitoring/spec.md.
  # With no DSN in test, Sentry.Test collects the raw event (before_send does not run), so each
  # test scrubs it with Maya.ErrorMonitor.scrub/1 and checks what would go over the wire.

  @endpoint MayaWeb.Endpoint
  @question "How do I earn Roxanne's badge?"
  @answer "Lead with Mudkip against Nosepass."

  setup {Req.Test, :set_req_test_to_shared}

  setup do
    Sentry.Test.start_collecting_sentry_reports()
  end

  defp sent(event), do: event |> Maya.ErrorMonitor.scrub() |> Sentry.Client.render_event()

  test "before_send is the scrubber, and test has no DSN so nothing leaves" do
    assert Application.get_env(:sentry, :before_send) == {Maya.ErrorMonitor, :scrub}
    assert Application.get_env(:sentry, :dsn) == nil
  end

  test "a crashed agent Task reaches Sentry with its stack and stage tag, and no content" do
    :ok = Maya.GameData.import!()
    id = "guest-#{System.unique_integer([:positive])}"

    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/transcriptions"} = conn ->
        Req.Test.json(conn, %{"text" => @question})

      conn ->
        send_resp(conn, 500, "")
    end)

    # The first turn stores an Answer, so the crashing turn's Conversation holds one.
    Req.Test.stub(Maya.OpenRouter, fn conn ->
      content = Jason.encode!(%{answer: @answer, used_tool_calls: []})
      Req.Test.json(conn, %{"choices" => [%{"message" => %{"content" => content}}]})
    end)

    {:ok, pid} = Conversation.start_or_find(id)
    on_exit(fn -> Conversation.stop(id) end)
    :ok = Sentry.Test.allow_sentry_reports(self(), pid)
    Conversation.subscribe(id)

    capture_log(fn ->
      Conversation.question(id, "RIFF", "question.wav")
      assert_receive {:conversation, {:turns, [%{answer: @answer}]}}, 2_000

      Req.Test.stub(Maya.OpenRouter, fn _conn -> raise "boom" end)
      Conversation.question(id, "RIFF", "question.wav")

      assert_receive {:conversation, {:turns, [_, %{id: turn_id}]}} when is_integer(turn_id),
                     2_000
    end)

    assert [event] = Sentry.Test.pop_sentry_reports()
    assert [%{type: "RuntimeError", stacktrace: %{frames: [_ | _]}}] = event.exception
    assert event.tags.stage == :agent
    assert event.environment == "test"

    body = sent(event) |> Jason.encode!()
    assert body =~ "RuntimeError"
    refute body =~ "Roxanne"
    refute body =~ "Mudkip"
    refute body =~ id
  end

  test "a warning is a breadcrumb on the next error, never its own event" do
    capture_log(fn ->
      task =
        Task.Supervisor.async_nolink(Maya.TaskSupervisor, fn ->
          Logger.warning("tts failed: :timeout")
          raise "boom"
        end)

      assert {:exit, _} = Task.yield(task, 1_000)
    end)

    assert [event] = Sentry.Test.pop_sentry_reports()
    assert [%{message: "tts failed: :timeout"}] = sent(event).breadcrumbs
  end

  test "a controller error sends no cookie, header or body" do
    # The smoke route with a token runs the agent, whose stub raises inside the request.
    previous = Application.get_env(:maya, :smoke_token)
    Application.put_env(:maya, :smoke_token, "secret")
    on_exit(fn -> Application.put_env(:maya, :smoke_token, previous) end)
    Req.Test.stub(Maya.OpenRouter, fn _conn -> raise "boom" end)
    :ok = Maya.GameData.import!()

    conn =
      build_conn()
      |> put_req_header("cookie", "_maya_key=guest-cookie-value")
      |> put_req_header("x-smoke-token", "secret")

    capture_log(fn ->
      try do
        post(conn, "/health/ask", %{question: @question})
      rescue
        _ -> :raised
      end
    end)

    assert [event] = Sentry.Test.pop_sentry_reports()
    assert [%{type: "RuntimeError"}] = event.exception

    body = sent(event) |> Jason.encode!()
    refute body =~ "guest-cookie-value"
    refute body =~ "secret"
    refute body =~ "Roxanne"
  end

  test "strings that quote data or run long are dropped, short reasons stay" do
    event = %Sentry.Event{
      event_id: "1",
      timestamp: "2026-11-21T00:00:00",
      message: %Sentry.Interfaces.Message{formatted: ~s(no match: {:ok, "#{@question}"})},
      exception: [%Sentry.Interfaces.Exception{type: "MatchError", value: ~s("#{@question}")}],
      breadcrumbs: [
        %Sentry.Interfaces.Breadcrumb{message: "agent failed: {:http, 500}"},
        %Sentry.Interfaces.Breadcrumb{message: String.duplicate("a", 200)}
      ],
      request: %Sentry.Interfaces.Request{cookies: %{"_maya_key" => "x"}, data: @question},
      user: %{id: "guest-1"},
      extra: %{state: @question},
      tags: %{stage: :tts, guest: "guest-1"}
    }

    body = event |> sent() |> Jason.encode!()
    refute body =~ "Roxanne"
    refute body =~ "guest-1"
    refute body =~ "_maya_key"
    assert body =~ "agent failed: {:http, 500}"
    assert body =~ "MatchError"
    assert Maya.ErrorMonitor.scrub(event).tags == %{stage: :tts}
  end
end
