defmodule Maya.Agent.Tools do
  @moduledoc """
  The agent's tools (ARCHITECTURE.md 3): JSON definitions sent on every request, and a thin
  shell that reads the game data and hands it to the pure `Maya.Agent.Facts`.
  """

  alias Maya.Agent.Facts
  alias Maya.Events
  alias Maya.GameData

  @definitions [
    %{
      type: "function",
      function: %{
        name: "gym_counter",
        description:
          "A gym leader's team and levels, the player's Team with type matchups against the leader's ace, and a suggested lead.",
        parameters: %{
          type: "object",
          properties: %{leader: %{type: "string", description: "Gym leader name, e.g. Roxanne"}},
          required: ["leader"]
        }
      }
    },
    %{
      type: "function",
      function: %{
        name: "find_pokemon",
        description:
          "A Pokémon's types, evolutions and the wild places (with rates) where it can be caught.",
        parameters: %{
          type: "object",
          properties: %{name: %{type: "string", description: "Pokémon name, e.g. Ralts"}},
          required: ["name"]
        }
      }
    },
    %{
      type: "function",
      function: %{
        name: "log_event",
        description:
          "Records what the player just told you about their game and updates their Progress. Returns a confirm line to say, or a refused line to say instead.",
        parameters: %{
          type: "object",
          properties: %{
            kind: %{type: "string", enum: Events.kinds()},
            details: %{
              type: "object",
              description:
                "badge_earned: leader or badge (number). caught: species, level. evolved: from, to. level_up: species, level. moved: location. undo: nothing.",
              properties: %{
                leader: %{type: "string"},
                badge: %{type: "integer"},
                species: %{type: "string"},
                level: %{type: "integer"},
                from: %{type: "string"},
                to: %{type: "string"},
                location: %{type: "string"}
              }
            }
          },
          required: ["kind"]
        }
      }
    }
  ]

  def definitions, do: @definitions

  @doc "Runs one tool with decoded arguments against Progress."
  def call("gym_counter", %{"leader" => leader}, progress) when is_binary(leader) do
    gym = Facts.gym(leader)
    trainer = gym && GameData.trainer(gym.party)
    species = if trainer, do: Enum.map(trainer.pokemon, & &1.species), else: []
    types = types(species ++ Enum.map(progress.team, & &1["species"]))
    Facts.gym_counter(gym, trainer, progress, types, GameData.type_chart())
  end

  def call("find_pokemon", %{"name" => name}, progress) when is_binary(name) do
    case GameData.species(Facts.species_name(name)) do
      nil -> {:error, :not_found}
      s -> Facts.find_pokemon(s, GameData.encounters(s.name), GameData.locations(), progress)
    end
  end

  # Writes, so its result carries the new Progress for the rest of the turn.
  def call("log_event", %{"kind" => kind} = args, progress) when is_binary(kind) do
    details = if is_map(args["details"]), do: args["details"], else: %{}

    case Events.log(progress, kind, details) do
      {:ok, line, new_progress} -> {:logged, line, new_progress}
      refused -> refused
    end
  end

  def call(name, _args, _progress) when name in ["gym_counter", "find_pokemon", "log_event"],
    do: {:error, :bad_arguments}

  def call(_name, _args, _progress), do: {:error, :unknown_tool}

  defp types(names) do
    for name <- Enum.uniq(names), s = GameData.species(name), into: %{}, do: {name, s.types}
  end

  @doc "A tool result as the JSON content of its `role: \"tool\"` message."
  def encode({:ok, fact}, _progress), do: Jason.encode!(%{fact: fact})
  def encode({:logged, line, _new_progress}, _progress), do: Jason.encode!(%{confirm: line})
  def encode({:refused, line}, _progress), do: Jason.encode!(%{refused: line})

  def encode({:error, :past_horizon}, progress),
    do: Jason.encode!(%{error: "past_horizon", hint: Facts.hint(progress)})

  def encode({:error, reason}, _progress), do: Jason.encode!(%{error: reason})
end
