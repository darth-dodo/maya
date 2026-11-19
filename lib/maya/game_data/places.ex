defmodule Maya.GameData.Places do
  @moduledoc """
  Trainer and item places, pure, on the decoded `priv/data/` files. Every row gets the
  `badges_required` of its own map: a listed location's, or a hand-listed interior's
  (`interiors.json`), never the city's by inheritance. Gifts (`gifts.json`) keep their own.
  """

  @doc """
  Every problem, `[]` when clean: an interior or gift whose city is unlisted or needs more
  badges than it, a place row on a map that is neither listed nor an interior, a gift item
  not in `items.json`, a trainer label not in `trainers.json`, or an `access.json` row that
  matches no fetched item or trainer place.
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

    fetched = MapSet.new(data.item_places ++ data.trainer_places, &access_key/1)

    access_problems =
      for a <- data.access["items"] ++ data.access["trainers"],
          not MapSet.member?(fetched, access_key(a)) or not is_integer(a["badges_required"]),
          do: {a["map"], :unknown_access}

    hand ++
      unlisted ++
      access_problems ++
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

  @doc """
  `trainer_places` table rows, each under its location with its map's badges, raised for a
  trainer reachable only with an HM or from a later map (`access.json`).
  """
  def trainer_rows(data) do
    maps = by_map(data.locations, data.interiors)
    access = access(data)

    for t <- data.trainer_places, place = maps[t["map"]] do
      %{
        "map" => t["map"],
        "location" => place.location,
        "badges_required" => max(place.badges_required, access[access_key(t)] || 0),
        "trainer_label" => t["label"],
        "name" => t["name"]
      }
    end
  end

  @doc """
  `item_places` table rows: fetched places with their map's badges, raised for a ball or hidden
  item reachable only with an HM or from a later map (`access.json`), then gifts with their own.
  """
  def item_rows(data) do
    maps = by_map(data.locations, data.interiors)
    access = access(data)

    fetched =
      for i <- data.item_places, place = maps[i["map"]] do
        badges = max(place.badges_required, access[access_key(i)] || 0)
        Map.merge(i, %{"location" => place.location, "badges_required" => badges})
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

  # An item row is keyed by map, item and how; a trainer row by map and label.
  defp access_key(row), do: {row["map"], row["item"] || row["label"], row["how"]}

  defp access(data),
    do:
      Map.new(
        data.access["items"] ++ data.access["trainers"],
        &{access_key(&1), &1["badges_required"]}
      )

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
