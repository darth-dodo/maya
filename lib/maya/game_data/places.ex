defmodule Maya.GameData.Places do
  @moduledoc """
  Trainer and item places, pure, on the decoded `priv/data/` files. Every row gets the
  `badges_required` of its own map: a listed location's, or a hand-listed interior's
  (`interiors.json`), never the city's by inheritance. Gifts (`gifts.json`) keep their own.
  """

  @doc """
  Every problem, `[]` when clean: an interior or gift whose city is unlisted or needs more
  badges than it, a place row on a map that is neither listed nor an interior, a gift item
  not in `items.json`, or a trainer label not in `trainers.json`.
  """
  def problems(%{} = data) do
    required = Map.new(data.locations, &{&1["name"], &1["badges_required"]})
    maps = by_map(data.locations, data.interiors)
    labels = MapSet.new(data.trainers, & &1["label"])

    hand =
      for row <- data.interiors ++ data.gifts,
          problem = hand_problem(row, required),
          do: {row["map"], problem}

    unlisted =
      for row <- data.trainer_places ++ data.item_places,
          not Map.has_key?(maps, row["map"]),
          uniq: true,
          do: {row["map"], :unlisted_map}

    hand ++
      unlisted ++
      for(g <- data.gifts, g["item"] not in data.items, do: {g["item"], :unknown_item}) ++
      for t <- data.trainer_places, t["label"] not in labels, do: {t["label"], :unknown_trainer}
  end

  defp hand_problem(%{"city" => city, "badges_required" => badges}, required) do
    cond do
      not Map.has_key?(required, city) -> :unlisted_city
      not is_integer(badges) or badges < required[city] -> :badge_below
      true -> nil
    end
  end

  @doc "`trainer_places` table rows, each under its location with its map's badges."
  def trainer_rows(data) do
    maps = by_map(data.locations, data.interiors)

    for t <- data.trainer_places, place = maps[t["map"]] do
      %{
        "map" => t["map"],
        "location" => place.location,
        "badges_required" => place.badges_required,
        "trainer_label" => t["label"],
        "name" => t["name"]
      }
    end
  end

  @doc "`item_places` table rows: fetched places with their map's badges, then gifts with their own."
  def item_rows(data) do
    maps = by_map(data.locations, data.interiors)

    fetched =
      for i <- data.item_places, place = maps[i["map"]] do
        Map.merge(i, %{"location" => place.location, "badges_required" => place.badges_required})
      end

    fetched ++
      for g <- data.gifts,
          do: %{
            "item" => g["item"],
            "map" => g["map"],
            "location" => g["city"],
            "how" => g["how"],
            "badges_required" => g["badges_required"]
          }
  end

  defp by_map(locations, interiors) do
    Map.new(
      Enum.map(
        locations,
        &{&1["map"], %{location: &1["name"], badges_required: &1["badges_required"]}}
      ) ++
        Enum.map(
          interiors,
          &{&1["map"], %{location: &1["city"], badges_required: &1["badges_required"]}}
        )
    )
  end
end
