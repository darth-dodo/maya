# A Conversation turn crosses several processes (timer, STT, agent, TTS, DB write), and on a
# shared CI runner that took over the 100 ms default (#64, #137). assert_receive still returns
# on the first match; refute_receive keeps its 100 ms.
ExUnit.start(assert_receive_timeout: 1_000)
Ecto.Adapters.SQL.Sandbox.mode(Maya.Repo, :manual)
