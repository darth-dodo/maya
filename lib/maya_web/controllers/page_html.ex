defmodule MayaWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use MayaWeb, :html

  embed_templates "page_html/*"

  # Before the first gym only; each fact's source: openspec/changes/archive/*-home-poke-facts/design.md
  # The CSS rotation in app.css times 12 items: update both together.
  @poke_facts [
    "Mudkip is a pure Water type, and Maya is not biased at all.",
    "Treecko is a pure Grass type.",
    "Torchic is a pure Fire type.",
    "All three Hoenn starters evolve at level 16 and again at level 36.",
    "Poochyena is a Dark type found on every route from 101 to 104 and in Petalburg Woods.",
    "Zigzagoon is a Normal type you can meet on Routes 101, 102 and 103.",
    "Wurmple evolves at level 7 into either Silcoon or Cascoon.",
    "Ralts hides in the Route 102 grass with just a 4 percent encounter rate.",
    "Seedot is the rarest find on Route 102: a 1 percent encounter.",
    "Lotad is a Water and Grass type living in the Route 102 grass.",
    "Wingull is a Water and Flying type that turns up on Routes 103 and 104.",
    "Slakoth naps in Petalburg Woods and shows up in 5 percent of encounters there."
  ]

  def poke_facts, do: @poke_facts
end
