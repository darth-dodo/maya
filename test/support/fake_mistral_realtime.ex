defmodule Maya.FakeMistralRealtime do
  @moduledoc """
  A test-only Voxtral realtime endpoint on Bandit (design.md, Testing the relay). It sends
  `session.created`, reports every client message to the test process and answers by `mode`:
  `:ok` sends one delta per audio message, then on end of audio the deltas left and
  `transcription.done` (the real API sends the last deltas after `input_audio.end`), `:error`
  sends an error event, `:close` closes the socket, `:garbage` sends a frame that is not JSON,
  `:stall` never finishes. `Maya.FakeMistralRealtimePlug` does the upgrade.
  """
  @behaviour WebSock

  @doc "Starts the fake on a free port and points the relay at it; returns the port."
  def serve(mode, deltas \\ ["where do", " I catch", " Ralts"]) do
    opts = %{test: self(), mode: mode, deltas: deltas}

    pid =
      ExUnit.Callbacks.start_supervised!(
        {Bandit,
         plug: {Maya.FakeMistralRealtimePlug, opts}, port: 0, ip: :loopback, startup_log: false}
      )

    {:ok, {_ip, port}} = ThousandIsland.listener_info(pid)
    point_relay_at("ws://127.0.0.1:#{port}/v1/audio/transcriptions/realtime")
    port
  end

  @doc "Sets the relay URL for this test and restores it afterwards."
  def point_relay_at(url) do
    voice = Application.fetch_env!(:maya, :voice)
    Application.put_env(:maya, :voice, Keyword.put(voice, :stt_realtime_url, url))
    ExUnit.Callbacks.on_exit(fn -> Application.put_env(:maya, :voice, voice) end)
  end

  @impl true
  def init(state) do
    send(state.test, {:fake_socket, self()})
    {:push, text(%{type: "session.created", session: %{}}), state}
  end

  @impl true
  def handle_in({json, opcode: :text}, state) do
    msg = Jason.decode!(json)
    send(state.test, {:fake_got, msg})
    answer(msg["type"], state)
  end

  @impl true
  def handle_info(_msg, state), do: {:ok, state}

  defp answer("session.update", state),
    do: {:push, text(%{type: "session.updated", session: %{}}), state}

  defp answer("input_audio.append", %{mode: :ok, deltas: [delta | rest]} = state),
    do: {:push, text(%{type: "transcription.text.delta", text: delta}), %{state | deltas: rest}}

  defp answer("input_audio.append", %{mode: :error} = state),
    do: {:push, text(%{type: "error", error: %{message: "bad audio", code: 3001}}), state}

  defp answer("input_audio.append", %{mode: :close} = state), do: {:stop, :normal, 1011, state}

  defp answer("input_audio.append", %{mode: :garbage} = state),
    do: {:push, {:text, "where do I catch {"}, state}

  defp answer("input_audio.end", %{mode: :ok} = state) do
    late = Enum.map(state.deltas, &text(%{type: "transcription.text.delta", text: &1}))
    done = %{type: "transcription.done", text: "where do I catch Ralts", segments: []}
    {:push, late ++ [text(done)], %{state | deltas: []}}
  end

  defp answer(_type, state), do: {:ok, state}

  defp text(map), do: {:text, Jason.encode!(map)}
end
