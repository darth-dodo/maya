defmodule Maya.Horizon do
  @moduledoc """
  The Spoiler horizon as pure functions over Progress (`%{badges: [1..8]}`).

  The horizon is everything up to and including the Next gym. A location is
  allowed only when it is known and its `badges_required` is at most the
  badges earned; anything else fails closed.
  """

  # The one place the gym order lives; `party` is the leader's first party label in pokeemerald.
  @gyms [
    %{badge: 1, leader: "Roxanne", city: "Rustboro City", party: "Roxanne1"},
    %{badge: 2, leader: "Brawly", city: "Dewford Town", party: "Brawly1"},
    %{badge: 3, leader: "Wattson", city: "Mauville City", party: "Wattson1"},
    %{badge: 4, leader: "Flannery", city: "Lavaridge Town", party: "Flannery1"},
    %{badge: 5, leader: "Norman", city: "Petalburg City", party: "Norman1"},
    %{badge: 6, leader: "Winona", city: "Fortree City", party: "Winona1"},
    %{badge: 7, leader: "Tate and Liza", city: "Mossdeep City", party: "TateAndLiza1"},
    %{badge: 8, leader: "Juan", city: "Sootopolis City", party: "Juan1"}
  ]

  @doc "All 8 gyms in badge order."
  def gyms, do: @gyms

  @doc "The first gym whose badge is not in Progress, or nil with all 8."
  def next_gym(%{badges: badges}), do: Enum.find(@gyms, &(&1.badge not in badges))

  @doc "The number of distinct badges 1 to 8 in Progress."
  def badges_earned(%{badges: badges}),
    do: badges |> Enum.filter(&(&1 in 1..8)) |> Enum.uniq() |> length()

  @doc "Whether a location (a `locations` row, or nil when unlisted) is inside the horizon."
  def allowed?(%{badges_required: required}, progress) when is_integer(required),
    do: required <= badges_earned(progress)

  def allowed?(_unlisted, _progress), do: false
end
