defmodule Mix.Tasks.Maya.Import do
  @shortdoc "Loads game data and the Progress seed into Postgres from priv/ (no network)"
  @moduledoc """
  Replaces the game data tables from `priv/data/` and seeds Progress from
  `priv/progress.json` when there is none. Safe to run again. In a release use
  `bin/maya eval "Maya.Release.import_data()"`.
  """
  use Mix.Task

  @requirements ["app.start"]

  @impl Mix.Task
  def run(_args) do
    :ok = Maya.GameData.import!()
    Mix.shell().info("Imported game data from priv/data/")
  end
end
