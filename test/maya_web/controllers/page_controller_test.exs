defmodule MayaWeb.PageControllerTest do
  # No database: the home page reads none, so this runs without the SQL sandbox.
  # Not async: the clip tests add a fixture clip under priv/static that every request to / sees.
  use ExUnit.Case, async: false

  import Plug.Conn
  import Phoenix.ConnTest
  use MayaWeb, :verified_routes

  @endpoint MayaWeb.Endpoint

  # Scenarios from openspec/specs/landing-page/spec.md (the public home page at /).

  @later_leaders ~w(Brawly Wattson Flannery Norman Winona Tate Liza Juan)
  @evolved_starters ~w(Grovyle Sceptile Combusken Blaziken Marshtomp Swampert)
  @videos Path.join(:code.priv_dir(:maya), "static/videos")

  defp home, do: build_conn() |> get(~p"/") |> html_response(200)

  defp doc(html), do: LazyHTML.from_document(html)
  defp query(html, selector), do: html |> doc() |> LazyHTML.query(selector)
  defp text_of(html, selector), do: html |> query(selector) |> LazyHTML.text() |> String.trim()
  defp count(html, selector), do: html |> query(selector) |> Enum.count()
  defp attrs(html, selector, name), do: html |> query(selector) |> LazyHTML.attribute(name)

  test "visitor without a login opens the home page" do
    conn = get(build_conn(), ~p"/")
    html = html_response(conn, 200)

    assert text_of(html, "header a[href='/']") == "Maya"
    assert count(html, "h1") == 1
    assert text_of(html, "h1#home-heading") == "Maya"
    assert text_of(html, "#home-tagline") == "Maps, Answers, Yaps, Advice."

    assert text_of(html, "#home-catchphrase") ==
             "So I hear you like Mudkip. Good. Correct choice."

    for id <- ~w(#talk-screen #talk-heading #talk-button), do: assert(count(html, id) == 0, id)
  end

  test "way in for friends links to the Talk screen" do
    assert attrs(home(), "#talk-link", "href") == ["/talk"]
  end

  test "browser tab title is Maya and generator content is gone" do
    html = home()

    assert text_of(html, "head title") == "Maya"
    body = text_of(html, "body")
    refute body =~ "Peace of mind from prototype to production"
    refute body =~ "Phoenix Framework"

    for href <- attrs(html, "a[href]", "href"),
        bad <- ~w(github.com/phoenixframework phoenixframework.org hexdocs.pm),
        do: refute(href =~ bad, href)
  end

  test "hero holds the CSS Emerald ball, the heading, tagline and catchphrase" do
    html = home()

    for id <- ~w(#pokeball.pokeball-emerald #home-heading #home-tagline #home-catchphrase),
        do: assert(count(html, "#home-hero #{id}") == 1, id)

    assert count(html, "#pokeball img") == 0
  end

  test "static page: no LiveView and no Conversation" do
    conn = get(build_conn(), ~p"/")
    html = html_response(conn, 200)

    assert count(html, "[data-phx-main]") == 0
    guest = get_session(conn, :guest_id)
    assert Registry.lookup(Maya.ConversationRegistry, {:conversation, guest}) == []
  end

  test "only own assets, no frames, every img a captioned screenshot of Maya" do
    html = home()

    refs =
      attrs(html, "[src]", "src") ++
        attrs(html, "[poster]", "poster") ++ attrs(html, "link[rel=stylesheet]", "href")

    assert refs != []

    for ref <- refs,
        do: assert(String.starts_with?(ref, "/") and not String.starts_with?(ref, "//"), ref)

    assert count(html, "iframe, embed") == 0

    for img <- query(html, "img") do
      assert [src] = LazyHTML.attribute(img, "src")
      assert String.starts_with?(src, "/images/demo/")
      assert [alt] = LazyHTML.attribute(img, "alt")
      assert String.trim(alt) != ""
    end
  end

  # shortcut: assumes the clip is absent, delete this test in the PR that adds the clip.
  test "screenshots before the clip: 1 to 4 real ones, no video" do
    refute File.exists?(Path.join(@videos, "maya-demo.mp4"))
    html = home()

    srcs = attrs(html, "#demo img", "src")
    assert length(srcs) in 1..4
    assert count(html, "#demo video") == 0

    for src <- srcs do
      path = Path.join(:code.priv_dir(:maya), "static" <> src)
      assert File.exists?(path), "missing #{src}"
      assert File.stat!(path).size < 300_000, "#{src} over 300 KB"
    end
  end

  describe "with the clip" do
    setup do
      clip = Path.join(@videos, "maya-demo.mp4")

      # Until the real clip lands: a tiny stand-in clip and transcript, removed again even
      # when the test fails. Once it lands these tests check the real files.
      unless File.exists?(clip) do
        File.mkdir_p!(@videos)
        transcript = Path.join(@videos, "maya-demo.txt")
        File.write!(clip, "not really a video")
        File.write!(transcript, "Maya answers a Question on the Talk screen.")

        on_exit(fn ->
          File.rm(clip)
          File.rm(transcript)
          File.rmdir(@videos)
        end)
      end

      %{clip: clip}
    end

    test "clip present: muted inline video with poster, captions and a transcript" do
      html = home()

      assert count(html, "#demo img") == 0
      video = query(html, "#demo video#demo-video")
      assert Enum.count(video) == 1

      for name <- ~w(muted playsinline controls),
          do: assert(LazyHTML.attribute(video, name) != [], name)

      assert LazyHTML.attribute(video, "autoplay") == []
      assert [poster] = LazyHTML.attribute(video, "poster")
      assert String.starts_with?(poster, "/")

      assert attrs(html, "#demo-video source[type='video/mp4']", "src") == [
               "/videos/maya-demo.mp4"
             ]

      assert [vtt] = attrs(html, "#demo-video track[kind=captions]", "src")
      assert String.starts_with?(vtt, "/") and String.ends_with?(vtt, ".vtt")
      assert text_of(html, "#demo-transcript") != ""
    end

    test "size budget: under 5 MB and served as video/mp4", %{clip: clip} do
      assert File.stat!(clip).size < 5_000_000

      conn = get(build_conn(), "/videos/maya-demo.mp4")
      assert conn.status == 200
      assert get_resp_header(conn, "content-type") |> hd() =~ "video/mp4"
    end
  end

  test "voice loop: four steps in order and no invented latency" do
    html = home()

    assert html |> query("#voice-loop ol .loop-step") |> Enum.map(&String.trim(LazyHTML.text(&1))) ==
             ["Hold", "Transcribe", "Agent with tools", "Speak"]

    assert count(html, "#latency-pending") == 1
    refute text_of(html, "#voice-loop") =~ ~r/\d+(\.\d+)?\s?(ms|s)\b/
  end

  test "spoiler promise: three promises, each with text" do
    html = home()

    for id <- ~w(#promise-facts #promise-horizon #promise-ci-gate),
        do: assert(text_of(html, "#spoiler-promise #{id}") != "", id)
  end

  test "gate wording stays honest while CI has no spoiler job" do
    ci = File.read!(Path.expand("../../../.github/workflows/ci.yml", __DIR__))
    spoiler_job? = Regex.match?(~r/^  [\w-]*spoiler[\w-]*:\s*$/m, ci)

    if spoiler_job? do
      refute text_of(home(), "#promise-ci-gate") =~ "planned"
    else
      assert text_of(home(), "#promise-ci-gate") =~ "planned"
    end
  end

  test "home page stays spoiler-free" do
    page = text_of(home(), "html")

    for name <- @later_leaders ++ @evolved_starters,
        do: refute(page =~ name, "#{name} on the home page")
  end

  test "footer links the factory, the repo and its README, with inline art" do
    html = home()
    hrefs = attrs(html, "#site-footer a", "href")

    for href <- [
          "/factory",
          "https://github.com/darth-dodo/maya",
          "https://github.com/darth-dodo/maya#readme"
        ],
        do: assert(href in hrefs, href)

    svg = query(html, "#site-footer svg")
    refute Enum.empty?(svg)

    assert LazyHTML.attribute(svg, "aria-hidden") == ["true"] or
             not Enum.empty?(LazyHTML.query(svg, "title"))
  end
end
