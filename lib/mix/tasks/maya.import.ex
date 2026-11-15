defmodule Mix.Tasks.Maya.Import do
  @shortdoc "Loads game data into Postgres from priv/data/ (no network)"
  @moduledoc """
  Replaces the game data tables from `priv/data/`. Progress is seeded per guest on
  first use, not here (ADR-008). Safe to run again. In a release use
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
