defmodule MayaWeb.PageController do
  @moduledoc """
  The public pages: the home page at `/` (openspec/specs/landing-page) and the factory page at
  `/factory` (openspec/specs/factory-page). Plain pages: no LiveView socket, no Conversation, so a
  visitor spends no API credit. The only pages search engines may index.
  """
  use MayaWeb, :controller

  def home(conn, _params) do
    render(conn, :home, indexable: true)
  end

  def factory(conn, _params) do
    render(conn, :factory, indexable: true, page_title: "Maya factory")
  end
end
