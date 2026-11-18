defmodule MayaWeb.SmokeControllerTest do
  # Not async: the tests change the global :smoke_token app env.
  use MayaWeb.ConnCase, async: false

  import Ecto.Query

  # Scenarios from openspec/specs/service-health/spec.md, "Smoke Question".

  @question "How do I earn Roxanne's badge?"

  setup do
    previous = Application.fetch_env(:maya, :smoke_token)
    Application.put_env(:maya, :smoke_token, "secret")

    on_exit(fn ->
      case previous do
        {:ok, value} -> Application.put_env(:maya, :smoke_token, value)
        :error -> Application.delete_env(:maya, :smoke_token)
      end
    end)
  end

  defp ask(conn, token) do
    conn
    |> put_req_header("x-smoke-token", token)
    |> post(~p"/health/ask", %{question: @question})
  end

  defp stub_answer(answer) do
    content = Jason.encode!(%{answer: answer, used_tool_calls: []})

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      Req.Test.json(conn, %{
        "choices" => [%{"message" => %{"role" => "assistant", "content" => content}}]
      })
    end)
  end

  test "answers 404 when no smoke token is configured", %{conn: conn} do
    Application.put_env(:maya, :smoke_token, nil)

    assert conn |> ask("") |> response(404)
  end

  test "answers 401 for a wrong token, without calling the agent", %{conn: conn} do
    Req.Test.stub(Maya.OpenRouter, fn _conn -> flunk("agent called") end)

    assert conn |> ask("wrong") |> json_response(401) == %{"error" => "unauthorized"}
  end

  test "answers the agent's Answer as JSON and stores no turn", %{conn: conn} do
    :ok = Maya.GameData.import!()
    stub_answer("Lead with Mudkip, Roxanne's rocks fear water.")

    assert conn |> ask("secret") |> json_response(200) == %{
             "answer" => "Lead with Mudkip, Roxanne's rocks fear water."
           }

    assert Maya.Voice.Turn.recent("smoke") == []
  end

  test "asks as the dedicated smoke Guest (ADR-008)", %{conn: conn} do
    :ok = Maya.GameData.import!()
    stub_answer("Mudkip would approve.")

    assert conn |> ask("secret") |> json_response(200)

    assert Maya.Repo.exists?(
             from p in "progress", where: p.guest_id == "smoke", select: p.guest_id
           )
  end

  test "answers 503 with the reason when the agent fails", %{conn: conn} do
    # Since guest sessions (#65) every Guest's Progress is seeded on first use, so the
    # failure left to catch is the model call itself.
    Req.Test.stub(Maya.OpenRouter, fn conn -> Plug.Conn.send_resp(conn, 500, "upstream down") end)

    assert conn |> ask("secret") |> json_response(503) == %{"error" => "{:http, 500}"}
  end
end
