defmodule MayaWeb.PageController do
  use MayaWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
