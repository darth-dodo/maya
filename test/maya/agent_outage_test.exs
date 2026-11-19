defmodule Maya.AgentOutageTest do
  # Not async: the sandbox mode is global, as in the Conversation outage tests (#191).
  use Maya.DataCase, async: false

  import ExUnit.CaptureLog

  alias Maya.Agent

  @guest "outage-agent"
  @notes_down "I can't reach my notes right now, ask again soon?"

  setup do
    :ok = Maya.GameData.import!()
    %{progress: Maya.GameData.progress(@guest)}
  end

  # Postgres down or paused (#192): the shared sandbox is switched off, so every query from
  # this process fails the way a lost pool does.
  defp db_down, do: Ecto.Adapters.SQL.Sandbox.mode(Repo, :manual)

  defp call(id, name, args),
    do: %{"id" => id, "type" => "function", "function" => %{"name" => name, "arguments" => args}}

  @calls [
    {"find_pokemon", ~s({"name":"Ralts"})},
    {"gym_counter", ~s({"leader":"Roxanne"})},
    {"move_learnset", ~s({"species":"Mudkip"})},
    {"search_guide", ~s({"location":"Route 102"})},
    {"find_trainer", ~s({"place":"Route 102"})},
    {"find_item", ~s({"name":"Potion"})},
    {"team_check", "{}"},
    {"log_event", ~s({"kind":"badge_earned","details":{"leader":"Roxanne"}})},
    {"set_setting", ~s({"name":"humor","value":60})}
  ]

  for {name, args} <- @calls do
    @name name
    @args args
    test "#{name} during a database outage is a notes_down tool error, never a crash", %{
      progress: progress
    } do
      db_down()

      log =
        capture_log(fn ->
          assert {%{role: "tool", tool_call_id: "c1", content: content}, ^progress} =
                   Agent.tool_message(call("c1", @name, @args), progress)

          assert Jason.decode!(content) == %{"error" => "notes_down"}
        end)

      assert log =~ "[warning] tool #{@name} failed: DBConnection.OwnershipError"
    end
  end

  test "a tool read during an outage ends the turn with the honest notes line", %{
    progress: progress
  } do
    me = self()

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      send(me, :request)

      Req.Test.json(conn, %{
        "choices" => [
          %{
            "message" => %{
              "role" => "assistant",
              "content" => nil,
              "tool_calls" => [call("c1", "find_pokemon", ~s({"name":"Ralts"}))]
            }
          }
        ]
      })
    end)

    db_down()

    capture_log(fn ->
      assert Agent.answer("Where is Ralts?", [], progress: progress) == {:ok, @notes_down}
    end)

    assert_received :request
    refute_received :request
  end
end
