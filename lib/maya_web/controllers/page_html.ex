defmodule MayaWeb.PageHTML do
  @moduledoc "Templates for the public pages (`page_html/home.html.heex`, `page_html/factory.html.heex`)."
  use MayaWeb, :html

  embed_templates "page_html/*"

  # Real Talk screen screenshots (seed Progress, empty Conversation), until the clip lands.
  @screenshots [
    %{
      src: "/images/demo/talk-idle.png",
      alt:
        "The Talk screen for a new trainer: Littleroot Town, Next gym Roxanne (Rock), Mudkip at level 5, 0 of 8 badges, a Poké fact and the Hold to talk button."
    },
    %{
      src: "/images/demo/talk-listening.png",
      alt:
        "The Talk screen while the button is held: a coral ring around the ball, Listening to you, and the button reads Release to send."
    }
  ]

  def screenshots, do: @screenshots
end
