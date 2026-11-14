defmodule Mix.Tasks.Maya.ImportTest do
  use Maya.DataCase, async: false

  test "loads the game data from priv/ and says so" do
    Mix.shell(Mix.Shell.Process)
    on_exit(fn -> Mix.shell(Mix.Shell.IO) end)

    Mix.Tasks.Maya.Import.run([])

    assert_received {:mix_shell, :info, ["Imported game data from priv/data/"]}
    assert %{name: "Roxanne"} = Maya.GameData.trainer("Roxanne1")
  end
end
