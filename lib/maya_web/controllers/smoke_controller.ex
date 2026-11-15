defmodule MayaWeb.SmokeController do
  @moduledoc """
  `POST /health/ask`: the scheduled post-deploy check asks one text Question and gets the
  agent's Answer, so a green CI with a broken production Answer is caught (#55, E3).
  Gated by the `x-smoke-token` header (SMOKE_TOKEN, read in config/runtime.exs); off without it.
  Skips STT and TTS, sends no history and stores no turn.
  """
  use MayaWeb, :controller

  def ask(conn, params) do
    token = Application.get_env(:maya, :smoke_token)
    given = conn |> get_req_header("x-smoke-token") |> List.first("")

    cond do
      token in [nil, ""] ->
        send_resp(conn, 404, "Not Found")

      not Plug.Crypto.secure_compare(given, token) ->
        conn |> put_status(401) |> json(%{error: "unauthorized"})

      true ->
        case Maya.Agent.answer(to_string(params["question"]), [], guest_id: "smoke") do
          {:ok, answer} -> json(conn, %{answer: answer})
          # Only the reason, like Conversation's log line: never a transcript or a key.
          {:error, reason} -> conn |> put_status(503) |> json(%{error: reason_text(reason)})
        end
    end
  end

  defp reason_text(reason) when is_atom(reason), do: Atom.to_string(reason)
  defp reason_text(reason), do: inspect(reason)
end
