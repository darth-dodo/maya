defmodule MayaWeb.PageHTML do
  @moduledoc "Templates for the public pages (`page_html/home.html.heex`, `page_html/factory.html.heex`)."
  use MayaWeb, :html

  embed_templates "page_html/*"

  # One real turn at Route 104, given by Abhishek on 2026-11-15. Median Answer time and turn
  # count as recorded in the tide-homepage proposal on 2026-11-15; update them together.
  @real_turn %{
    question: "Where do I go next?",
    answer:
      "Head north to Rustboro City for Roxanne. Mudkip's Water moves make it a short fight.",
    median_s: 4.95,
    turns: 145
  }

  # Maya's Dials as {name, value, locked?}, the same as her agent prompt and the seed humor.
  @dials [
    {"Humor", 75, false},
    {"Honesty", 90, false},
    {"Sass", 40, false},
    {"Mudkip hype", 100, false},
    {"Spoilers", 0, true}
  ]

  def real_turn, do: @real_turn
  def dials, do: @dials

  # median / 1 makes a whole number (say 5) a float, so it still prints as 5.00.
  def real_turn_caption(%{median_s: median, turns: turns}),
    do:
      "Median Answer time #{:erlang.float_to_binary(median / 1, decimals: 2)} s over #{turns} turns"
end
