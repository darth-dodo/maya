defmodule Maya.Release do
  @moduledoc """
  Used for executing DB release tasks when run in production without Mix
  installed.
  """
  @app :maya

  def migrate do
    load_app()

    for repo <- repos() do
      {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :up, all: true))
    end

    # Every deploy seeds game data; each guest seeds their own Progress on first use (ADR-008).
    import_data()
  end

  @doc "The release form of `mix maya.import`: loads game data from priv/data/."
  def import_data do
    load_app()
    {:ok, :ok, _} = Ecto.Migrator.with_repo(Maya.Repo, fn _repo -> Maya.GameData.import!() end)
  end

  def rollback(repo, version) do
    load_app()
    {:ok, _, _} = Ecto.Migrator.with_repo(repo, &Ecto.Migrator.run(&1, :down, to: version))
  end

  defp repos do
    Application.fetch_env!(@app, :ecto_repos)
  end

  defp load_app do
    # Many platforms require SSL when connecting to the database
    Application.ensure_all_started(:ssl)
    Application.ensure_loaded(@app)
  end
end
