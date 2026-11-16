defmodule Maya.GameData.Notes do
  @moduledoc """
  The Walkthrough notes checker: pure, on the decoded `walkthrough_notes.json` and
  `locations.json`. A note must be for a listed location, tagged at least that location's
  `badges_required`, and its text must name nothing past its own Spoiler horizon (fail closed).
  """

  alias Maya.Horizon

  @doc """
  Every problem in the notes, `[]` when they are clean. `forbidden` adds names (the spoiler
  probe list) that count as past the horizon unless they are part of a name inside it.
  """
  def problems(notes, locations, forbidden \\ []) do
    required = Map.new(locations, &{&1["name"], &1["badges_required"]})

    Enum.flat_map(notes, &note_problems(&1, required, locations, forbidden))
  end

  defp note_problems(
         %{"location" => location, "badges_required" => badges} = note,
         required,
         locations,
         forbidden
       ) do
    cond do
      not Map.has_key?(required, location) ->
        [{location, :unlisted}]

      not is_integer(badges) or badges < required[location] ->
        [{location, :badge_below}]

      true ->
        for name <- leaks(note["text"], badges, locations, forbidden),
            do: {location, {:names, name}}
    end
  end

  @doc "Names past a note's horizon (`badges` earned) that its text mentions."
  def leaks(text, badges, locations, forbidden \\ []) do
    {inside, past} = Enum.split_with(locations, &(&1["badges_required"] <= badges))
    {gyms_inside, gyms_past} = Enum.split_with(Horizon.gyms(), &(&1.badge <= badges + 1))

    allowed =
      Enum.map(inside, & &1["name"]) ++ Enum.flat_map(gyms_inside, &[&1.leader, &1.badge_name])

    candidates =
      Enum.map(past, & &1["name"]) ++
        Enum.flat_map(gyms_past, &[&1.leader, &1.badge_name, &1.city]) ++ forbidden

    for name <- Enum.uniq(candidates),
        not Enum.any?(allowed, &String.contains?(String.downcase(&1), String.downcase(name))),
        Regex.match?(~r/\b#{Regex.escape(name)}\b/i, text),
        do: name
  end
end
