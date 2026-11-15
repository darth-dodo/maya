defmodule Maya.Voice.Vocabulary do
  @moduledoc """
  Names STT should hear (Issue #68). `bias_terms/2` builds the Voxtral `context_bias` list
  from game data and Progress; `correct/2` snaps a near-miss name in the transcript to the
  known name. Terms only steer recognition: they are never shown or sent to the model.
  """

  alias Maya.{GameData, Horizon}

  @max_terms 400
  @threshold 0.86

  # English words within the threshold of a name, from Webster's Second (scripts/english_guard.exs).
  @guard_path Path.expand("../../../priv/data/english_guard.txt", __DIR__)
  @external_resource @guard_path
  @guard @guard_path |> File.read!() |> String.split() |> MapSet.new()

  def max_terms, do: @max_terms
  def threshold, do: @threshold

  @doc """
  Unique terms, most useful first: Maya, Mudkip, the Team, the Next gym leader, locations
  inside the horizon, then every species, gym leader, gym city and location. Capped at 400.
  """
  def bias_terms(progress, names \\ names()) do
    {inside, outside} = Enum.split_with(names.locations, &Horizon.allowed?(&1, progress))
    next = Horizon.next_gym(progress)

    (["Maya", "Mudkip"] ++
       for(%{"species" => s} <- progress.team, do: display(s)) ++
       List.wrap(next && next.leader) ++
       Enum.map(inside, & &1.name) ++
       Enum.map(names.species, &display/1) ++
       Enum.map(Horizon.gyms(), & &1.leader) ++
       Enum.map(Horizon.gyms(), & &1.city) ++
       Enum.map(outside, & &1.name))
    |> Enum.uniq()
    |> Enum.take(@max_terms)
  end

  # PokeAPI names as spoken: `ralts` is "Ralts", `mr-mime` is "Mr Mime".
  defp display(species),
    do: species |> String.split("-") |> Enum.map_join(" ", &String.capitalize/1)

  @doc "Species and location names from Postgres, cached until `refresh/0` (called by `GameData.import!/1`)."
  def names do
    with nil <- :persistent_term.get(__MODULE__, nil) do
      names = %{species: GameData.species_names(), locations: GameData.locations()}
      :persistent_term.put(__MODULE__, names)
      names
    end
  end

  def refresh, do: :persistent_term.erase(__MODULE__)

  @doc """
  The transcript with near-miss names snapped to the known name ("rawls" is "Ralts", "torch ick"
  is "Torchic"). English words on the guard list, words under 4 letters and exact names stay as
  spoken; punctuation and a possessive are kept.
  """
  def correct(transcript, terms) do
    names = for t <- terms, w <- String.split(t), into: %{}, do: {String.downcase(w), w}
    transcript |> String.split(" ") |> snap(names) |> Enum.join(" ")
  end

  defp snap([a, b | rest], names) do
    case join(a, b, names) do
      nil -> [fix(a, names) | snap([b | rest], names)]
      joined -> [joined | snap(rest, names)]
    end
  end

  defp snap(words, names), do: Enum.map(words, &fix(&1, names))

  defp fix(word, names) do
    with [pre, core, poss, post] <- parts(word),
         {name, score} when score < 1.0 <- match(core, names) do
      pre <> name <> poss <> post
    else
      _ -> word
    end
  end

  # Two words spoken apart ("torch ick") count only when together they beat each alone.
  defp join(a, b, names) do
    with [pre, wa, "", ""] <- parts(a),
         ["", wb, poss, post] <- parts(b),
         {name, score} <- match(wa <> wb, names),
         true <- score > max(score(wa, names), score(wb, names)) do
      pre <> name <> poss <> post
    else
      _ -> nil
    end
  end

  defp parts(word) do
    case Regex.run(~r/^(\P{L}*)(\p{L}+)('s|’s)?(\P{L}*)$/u, word) do
      [_, pre, core, poss, post] -> [pre, core, poss, post]
      _ -> nil
    end
  end

  defp score(word, names) do
    case match(word, names) do
      {_name, score} -> score
      nil -> 0.0
    end
  end

  defp match(word, names) do
    lower = String.downcase(word)

    cond do
      Map.has_key?(names, lower) -> {names[lower], 1.0}
      MapSet.member?(@guard, lower) -> nil
      true -> with {key, score} <- near(lower, Map.keys(names)), do: {names[key], score}
    end
  end

  @doc false
  # The closest name by Jaro distance, ignoring the guard; scripts/english_guard.exs builds the guard with it.
  def near(lower, keys) do
    keys
    |> Enum.filter(&candidate?(lower, &1))
    |> Enum.map(&{&1, String.jaro_distance(lower, &1)})
    |> Enum.max_by(&elem(&1, 1), fn -> nil end)
    |> case do
      {_key, score} = best when score >= @threshold -> best
      _ -> nil
    end
  end

  # Same first letter, length within 2, and not a prefix ("torch" is not "Torchic").
  defp candidate?(lower, key) do
    String.length(lower) >= 4 and String.first(lower) == String.first(key) and
      abs(String.length(lower) - String.length(key)) <= 2 and not String.starts_with?(key, lower)
  end
end
