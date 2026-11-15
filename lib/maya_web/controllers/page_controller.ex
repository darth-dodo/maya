defmodule MayaWeb.PageController do
  @moduledoc """
  The public home page at `/` (openspec/specs/landing-page). A plain page: no LiveView socket,
  no Conversation, so a visitor spends no API credit. The only page search engines may index.
  """
  use MayaWeb, :controller

  def home(conn, _params) do
    render(conn, :home, indexable: true, demo_transcript: demo_transcript())
  end

  # The demo slot shows the clip once Abhishek adds it with its transcript; screenshots until then.
  # Read per request so dropping the files in needs no recompile.
  defp demo_transcript do
    videos = Application.app_dir(:maya, "priv/static/videos")

    with true <- File.exists?(Path.join(videos, "maya-demo.mp4")),
         {:ok, text} <- File.read(Path.join(videos, "maya-demo.txt")) do
      String.trim(text)
    else
      _ -> nil
    end
  end
end
