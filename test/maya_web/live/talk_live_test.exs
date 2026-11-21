defmodule MayaWeb.TalkLiveTest do
  # Not async: the screen's Conversation runs outside the test process (shared sandbox and stubs).
  use MayaWeb.ConnCase, async: false

  import Ecto.Query
  import ExUnit.CaptureLog
  import Phoenix.LiveViewTest

  require Logger

  alias Maya.Voice.Turn

  setup {Req.Test, :set_req_test_to_shared}

  setup %{conn: conn} do
    :ok = Maya.GameData.import!()

    # The agent answers with the Question, so screen tests read one known text.
    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      question = List.last(Jason.decode!(body)["messages"])["content"]
      answer = Jason.encode!(%{answer: question, used_tool_calls: []})

      Req.Test.json(conn, %{
        "choices" => [%{"message" => %{"role" => "assistant", "content" => answer}}]
      })
    end)

    guest = "talk-#{System.unique_integer([:positive])}"
    on_exit(fn -> Maya.Conversation.stop(guest) end)
    %{guest: guest, conn: Plug.Test.init_test_session(conn, guest_id: guest)}
  end

  defp sse(type, extra),
    do: "event: #{type}\ndata: #{Jason.encode!(Map.put(extra, "type", type))}\n\n"

  defp stub(stt, tts) do
    Req.Test.stub(Maya.Mistral, fn
      %{request_path: "/v1/audio/transcriptions"} = conn -> stt.(conn)
      %{request_path: "/v1/audio/speech"} = conn -> tts.(conn)
    end)
  end

  defp text(text), do: &Req.Test.json(&1, %{"text" => text})

  defp speak(conn) do
    body =
      sse("speech.audio.delta", %{"audio_data" => Base.encode64(<<1, 2>>)}) <>
        sse("speech.audio.done", %{})

    Plug.Conn.send_resp(conn, 200, body)
  end

  # One hold: a stream start, two 200 ms chunks of silence and the end of the stream.
  defp ask(view, start \\ %{}) do
    button = element(view, "#talk-button")
    render_hook(button, "stream_start", start)

    for _ <- 1..2,
        do: render_hook(button, "audio_chunk", %{"audio" => Base.encode64(<<0::51_200>>)})

    render_hook(button, "stream_end", %{})
  end

  defp earn(guest, badges) do
    _ = Maya.GameData.progress(guest)

    query =
      from p in "progress",
        where: p.guest_id == ^guest,
        update: [set: [badges: type(^badges, {:array, :integer})]]

    {1, _} = Maya.Repo.update_all(query, [])
  end

  defp set_team(guest, species) do
    _ = Maya.GameData.progress(guest)
    team = for s <- species, do: %{"species" => s, "level" => 5}
    query = from p in "progress", where: p.guest_id == ^guest, update: [set: [team: ^team]]
    {1, _} = Maya.Repo.update_all(query, [])
  end

  @six ~w(mudkip poochyena wingull ralts zigzagoon lotad)

  describe "collapsible Team" do
    test "six members collapse to three names and +3", %{conn: conn, guest: guest} do
      set_team(guest, @six)
      {:ok, view, _html} = live(conn, ~p"/talk")

      refute has_element?(view, "#team-details[open]")

      assert view |> element("#team-summary") |> render() |> texts(".team-names") ==
               ["Mudkip, Poochyena, Wingull"]

      assert has_element?(view, "#team-summary .team-more", "+3")
      assert view |> element("#team") |> render() |> count(".mon") == 6
    end

    test "the accessible name lists the whole Team", %{conn: conn, guest: guest} do
      set_team(guest, @six)
      {:ok, view, _html} = live(conn, ~p"/talk")

      assert has_element?(
               view,
               ~s(#team-summary[aria-label="Team: Mudkip, Poochyena, Wingull, Ralts, Zigzagoon, Lotad"])
             )
    end

    test "two members show both names and no +", %{conn: conn, guest: guest} do
      set_team(guest, ~w(mudkip wingull))
      {:ok, view, _html} = live(conn, ~p"/talk")

      assert has_element?(view, "#team-summary .team-names", ~r/^\s*Mudkip, Wingull\s*$/)
      refute has_element?(view, "#team-summary .team-more")
    end

    test "an empty Team reads No Team yet", %{conn: conn, guest: guest} do
      set_team(guest, [])
      {:ok, view, _html} = live(conn, ~p"/talk")

      assert has_element?(view, "#team-summary .team-names", "No Team yet")
      assert has_element?(view, ~s(#team-summary[aria-label="Team: No Team yet"]))
    end

    test "a catch while collapsed updates the names", %{conn: conn, guest: guest} do
      set_team(guest, ~w(mudkip wingull))
      log_events()
      {:ok, view, _html} = live(conn, ~p"/talk")

      ask_and_hear(view, "I caught a Ralts at level 5")
      assert has_element?(view, "#team-summary .team-names", ~r/^\s*Mudkip, Wingull, Ralts\s*$/)
      refute has_element?(view, "#team-details[open]")
    end
  end

  # team-edit: the editor writes the same Events as voice.
  defp put_team(guest, members) do
    _ = Maya.GameData.progress(guest)
    team = for {s, l} <- members, do: %{"species" => s, "level" => l}
    query = from p in "progress", where: p.guest_id == ^guest, update: [set: [team: ^team]]
    {1, _} = Maya.Repo.update_all(query, [])
  end

  defp put_box(guest, members) do
    _ = Maya.GameData.progress(guest)
    box = for {s, l} <- members, do: %{"species" => s, "level" => l}
    query = from p in "progress", where: p.guest_id == ^guest, update: [set: [box: ^box]]
    {1, _} = Maya.Repo.update_all(query, [])
  end

  defp events(guest, kind) do
    Maya.Repo.aggregate(
      from(e in "events", where: e.guest_id == ^guest and e.kind == ^kind),
      :count
    )
  end

  defp chips(view), do: view |> element("#team") |> render() |> texts(".mon")

  defp open_editor(conn, guest, members, name) do
    put_team(guest, members)
    {:ok, view, _html} = live(conn, ~p"/talk")
    view |> element("#team .mon", name) |> render_click()
    view
  end

  @pair [{"mudkip", 16}, {"wingull", 9}]

  describe "Team editor" do
    test "Open the editor", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")

      assert has_element?(view, ~s(#team .mon[aria-label="Edit Wingull Lv 9"]))
      assert has_element?(view, "#team-editor[role=dialog] h2", "Wingull Lv 9")

      for label <- ["Save level", "Set as lead", "Move to PC box", "Remove", "PC box", "Close"],
          do: assert(has_element?(view, "#team-editor button", label))

      assert has_element?(view, "#team-editor input[name=level][value='9']")
      assert has_element?(view, "#team-editor label", "Level")
    end

    test "Close the editor", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      # Close and Escape focus the chip that opened the editor, by its slot id.
      assert has_element?(view, "#mon-2", "Wingull")
      assert has_element?(view, ~s(#team-editor-close[phx-click*="#mon-2"]))
      view |> element("#team-editor-close") |> render_click()
      refute has_element?(view, "#team-editor")

      view |> element("#mon-2") |> render_click()
      assert has_element?(view, ~s(#team-editor[phx-key="Escape"][phx-window-keydown*="#mon-2"]))
      render_keydown(view, "close_editor", %{"key" => "Escape"})
      refute has_element?(view, "#team-editor")
    end

    test "a tap on another chip switches the editor", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#team .mon", "Mudkip") |> render_click()
      assert has_element?(view, "#team-editor h2", "Mudkip Lv 16")
    end

    test "Not while talking", %{conn: conn, guest: guest} do
      put_team(guest, @pair)
      {:ok, view, _html} = live(conn, ~p"/talk")

      for state <- ~w(recording waiting speaking) do
        view |> element("#talk-button") |> render_hook("talk_state", %{"state" => state})
        view |> element("#team .mon", "Wingull") |> render_click()
        refute has_element?(view, "#team-editor")
      end

      view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "idle"})
      view |> element("#team .mon", "Wingull") |> render_click()
      assert has_element?(view, "#team-editor")
      view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "recording"})
      refute has_element?(view, "#team-editor")
    end

    test "Change a level", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> form("#level-form", %{"level" => "11"}) |> render_submit()

      assert events(guest, "set_level") == 1
      assert has_element?(view, "#team .mon", "Wingull Lv 11")
      assert has_element?(view, "#team-editor-line[role=status]", "Wingull is level 11 now.")
      assert has_element?(view, "#team-editor button", "Undo")
    end

    test "Level out of range", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")

      for level <- ~w(0 101) do
        view |> form("#level-form", %{"level" => level}) |> render_submit()
        assert has_element?(view, "#team-editor-line", "Levels go from 1 to 100.")
      end

      assert events(guest, "set_level") == 0
      refute has_element?(view, "#team-editor button", "Undo")
    end

    test "Set as lead", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#team-editor button", "Set as lead") |> render_click()

      assert chips(view) == ["Wingull Lv 9", "Mudkip Lv 16"]
      assert has_element?(view, "#team-summary .team-names", ~r/^\s*Wingull/)
      assert has_element?(view, "#team-editor h2", "Wingull Lv 9")
      assert events(guest, "set_lead") == 1
    end

    test "Move to the PC box", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#team-editor button", "Move to PC box") |> render_click()

      assert chips(view) == ["Mudkip Lv 16"]
      assert events(guest, "deposited") == 1
      assert has_element?(view, "#team-editor-line", "Wingull sent to the PC.")
    end

    test "Remove", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#team-editor button", "Remove") |> render_click()

      assert events(guest, "released") == 1
      assert chips(view) == ["Mudkip Lv 16"]
      assert has_element?(view, "#team-editor-line", "Wingull released from the Team.")
    end

    test "Undo", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#team-editor button", "Move to PC box") |> render_click()
      view |> element("#team-editor button", "Undo") |> render_click()

      assert chips(view) == ["Mudkip Lv 16", "Wingull Lv 9"]
      assert Maya.GameData.progress(guest).box == []
      assert has_element?(view, "#team-editor-line", "Undone, that Event is off the record.")
      refute has_element?(view, "#team-editor button", "Undo")
    end

    test "The last Team member", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, [{"mudkip", 16}], "Mudkip")
      view |> element("#team-editor button", "Move to PC box") |> render_click()

      assert has_element?(view, "#team-editor-line", "Your Team needs at least one Pokémon.")
      assert chips(view) == ["Mudkip Lv 16"]
      assert events(guest, "deposited") == 0
    end

    test "Same result as voice", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#team-editor button", "Move to PC box") |> render_click()

      voice = "voice-#{System.unique_integer([:positive])}"
      put_team(voice, @pair)

      {:ok, _line, _progress} =
        Maya.Events.log(Maya.GameData.progress(voice), "deposited", %{"species" => "wingull"})

      screen = Maya.GameData.progress(guest)
      by_voice = Maya.GameData.progress(voice)
      assert {screen.team, screen.box} == {by_voice.team, by_voice.box}
    end

    test "View and withdraw", %{conn: conn, guest: guest} do
      put_box(guest, [{"lotad", 6}])
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#editor-pc-box") |> render_click()

      assert has_element?(view, "#team-editor-heading", "PC box")
      assert has_element?(view, "#pc-box li", "Lotad Lv 6")
      view |> element(~s(#pc-box button[aria-label="Withdraw Lotad Lv 6"])) |> render_click()

      assert List.last(chips(view)) == "Lotad Lv 6"
      assert has_element?(view, "#team-editor-line", "Lotad level 6 joined the Team.")
      assert events(guest, "withdrawn") == 1
      assert has_element?(view, "#pc-box-empty", "The PC box is empty.")

      view |> element("#team-editor button", "Undo") |> render_click()
      assert chips(view) == ["Mudkip Lv 16", "Wingull Lv 9"]
      assert has_element?(view, "#pc-box li", "Lotad Lv 6")
    end

    test "the band opens the PC box with its count", %{conn: conn, guest: guest} do
      put_team(guest, @pair)
      put_box(guest, [{"lotad", 6}, {"ralts", 5}])
      {:ok, view, _html} = live(conn, ~p"/talk")

      assert has_element?(view, "#team-details #pc-box-open", "PC box (2)")
      refute has_element?(view, "#trainer-card #pc-box")
      view |> element("#pc-box-open") |> render_click()

      box = view |> element("#pc-box") |> render() |> texts("li span")
      assert box == ["Lotad Lv 6", "Ralts Lv 5"]
      assert has_element?(view, ~s(#team-editor-close[phx-click*="#pc-box-open"]))
    end

    test "Withdraw with a full Team", %{conn: conn, guest: guest} do
      full = [
        {"mudkip", 16},
        {"wingull", 9},
        {"zigzagoon", 4},
        {"ralts", 7},
        {"seedot", 8},
        {"lotad", 10}
      ]

      put_team(guest, full)
      put_box(guest, [{"poochyena", 5}])
      {:ok, view, _html} = live(conn, ~p"/talk")
      view |> element("#pc-box-open") |> render_click()
      view |> element(~s(#pc-box button[aria-label="Withdraw Poochyena Lv 5"])) |> render_click()

      assert has_element?(
               view,
               "#team-editor-line",
               "The Team is full at 6. Deposit one first, maybe Zigzagoon."
             )

      assert length(chips(view)) == 6
      assert events(guest, "withdrawn") == 0
      refute has_element?(view, "#team-editor button", "Undo")
    end

    test "Empty PC box", %{conn: conn, guest: guest} do
      put_team(guest, @pair)
      {:ok, view, _html} = live(conn, ~p"/talk")
      assert has_element?(view, "#pc-box-open", "PC box (0)")
      view |> element("#pc-box-open") |> render_click()

      assert has_element?(view, "#pc-box-empty", "The PC box is empty.")
      refute has_element?(view, "#pc-box")
    end

    test "the PC box only while idle", %{conn: conn, guest: guest} do
      put_team(guest, @pair)
      put_box(guest, [{"lotad", 6}])
      {:ok, view, _html} = live(conn, ~p"/talk")
      view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "recording"})
      view |> element("#pc-box-open") |> render_click()
      refute has_element?(view, "#team-editor")
      render_click(view, "withdraw", %{"slot" => 1})
      assert events(guest, "withdrawn") == 0

      view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "idle"})
      view |> element("#pc-box-open") |> render_click()
      view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "recording"})
      refute has_element?(view, "#team-editor")
    end

    test "the PC box follows a voice Event live", %{conn: conn, guest: guest} do
      put_team(guest, @pair)
      {:ok, view, _html} = live(conn, ~p"/talk")
      view |> element("#pc-box-open") |> render_click()

      {:ok, _line, progress} =
        Maya.Events.log(Maya.GameData.progress(guest), "deposited", %{"species" => "wingull"})

      send(view.pid, {:conversation, {:progress, progress}})
      assert has_element?(view, "#pc-box li", "Wingull Lv 9")
      assert has_element?(view, "#pc-box-open", "PC box (1)")
    end

    test "a stale or unknown withdraw changes nothing", %{conn: conn, guest: guest} do
      put_box(guest, [{"lotad", 6}])
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#editor-pc-box") |> render_click()
      put_box(guest, [{"ralts", 5}])
      view |> element(~s(#pc-box button[aria-label="Withdraw Lotad Lv 6"])) |> render_click()
      render_click(view, "withdraw", %{"slot" => "9"})
      render_click(view, "withdraw", %{})
      render_click(view, "withdraw", %{"slot" => %{"x" => 1}})

      assert has_element?(view, "#team-editor-line", "That Pokémon moved, so nothing changed.")
      assert events(guest, "withdrawn") == 0
    end

    test "Undo after Set as lead keeps the member in the editor", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      view |> element("#team-editor button", "Set as lead") |> render_click()
      assert has_element?(view, ~s(#team-editor-close[phx-click*="#mon-1"]))
      view |> element("#team-editor button", "Undo") |> render_click()

      assert chips(view) == ["Mudkip Lv 16", "Wingull Lv 9"]
      assert has_element?(view, "#team-editor h2", "Wingull Lv 9")
      assert has_element?(view, ~s(#team-editor-close[phx-click*="#mon-2"]))
    end

    test "unknown edit params are ignored", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      render_click(view, "edit", %{"kind" => "caught"})
      render_click(view, "save_level", %{})
      render_click(view, "edit_mon", %{"slot" => [1]})
      assert has_element?(view, "#team-editor h2", "Wingull Lv 9")
      assert events(guest, "caught") == 0
    end

    test "a stale chip changes nothing", %{conn: conn, guest: guest} do
      view = open_editor(conn, guest, @pair, "Wingull")
      put_team(guest, [{"mudkip", 16}, {"ralts", 5}])
      view |> element("#team-editor button", "Remove") |> render_click()

      assert has_element?(view, "#team-editor-line", "That Pokémon moved, so nothing changed.")
      assert events(guest, "released") == 0
    end
  end

  defp count(html, selector),
    do: html |> LazyHTML.from_fragment() |> LazyHTML.query(selector) |> Enum.count()

  defp texts(html, selector) do
    html
    |> LazyHTML.from_fragment()
    |> LazyHTML.query(selector)
    |> Enum.map(&(&1 |> LazyHTML.text() |> String.trim()))
  end

  test "the trainer card shows the seed Progress", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-screen #trainer-card #pokeball.pokeball-emerald")
    assert has_element?(view, "#trainer-card #location", "Littleroot Town")
    assert has_element?(view, "#next-gym strong", "Next gym: Roxanne")
    assert has_element?(view, "#next-gym .type-chip.type-rock", "Rock")
    assert has_element?(view, "#team .mon", "Mudkip Lv 5")
    assert view |> element("#team") |> render() |> count(".type-dot.type-water") == 1
    assert has_element?(view, "#badge-count", "0 of 8 badges")
  end

  test "earned badges move the Next gym and fill their slots", %{conn: conn, guest: guest} do
    earn(guest, [1, 2])
    {:ok, view, html} = live(conn, ~p"/talk")

    assert has_element?(view, "#next-gym strong", "Next gym: Wattson")
    assert has_element?(view, "#next-gym .type-chip.type-electric", "Electric")
    assert has_element?(view, "#badge-count", "2 of 8 badges")
    assert html |> count("#badge-case .badge-slot[data-earned='true']") == 2

    for later <- ~w(Flannery Norman Winona Tate Liza Juan),
        do: refute(has_element?(view, "#talk-screen", later), "#{later} on the page")
  end

  test "with all 8 badges the card says so and shows no type chip", %{conn: conn, guest: guest} do
    earn(guest, Enum.to_list(1..8))
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#next-gym", "All 8 badges earned")
    refute has_element?(view, "#next-gym .type-chip")
    assert has_element?(view, "#badge-count", "8 of 8 badges")
  end

  test "the screen root and status follow the Talk button's moments", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-screen[data-state='idle']")

    assert has_element?(
             view,
             "#talk-status[role='status'][aria-live='polite']",
             "Ready when you are"
           )

    for {state, status} <- [
          {"recording", "Listening to you…"},
          {"uploading", "Thinking…"},
          {"waiting", "Thinking…"},
          {"speaking", "Maya is speaking"},
          {"idle", "Ready when you are"}
        ] do
      view |> element("#talk-button") |> render_hook("talk_state", %{"state" => state})
      assert has_element?(view, "#talk-screen[data-state='#{state}']")
      assert has_element?(view, "#talk-status", status)
      assert has_element?(view, "#talk-status .wave[aria-hidden='true']") == (state == "speaking")
    end
  end

  test "an unknown moment is ignored", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")
    view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "recording"})
    view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "dancing"})

    assert has_element?(view, "#talk-screen[data-state='recording']")
  end

  describe "hold end report" do
    setup do
      level = Logger.level()
      Logger.configure(level: :info)
      on_exit(fn -> Logger.configure(level: level) end)
    end

    test "is logged at info with how and how long, nothing else", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      log =
        capture_log([level: :info], fn ->
          view
          |> element("#talk-button")
          |> render_hook("hold_ended", %{
            "ended_by" => "pointercancel",
            "hold_ms" => 840,
            "lost_capture" => true,
            "mic_open_ms" => 120,
            "warm" => false,
            "post_roll_ms" => 150
          })
        end)

      assert log =~
               "hold ended by pointercancel after 840 ms, lost capture: true, mic open: 120 ms, warm: false, post roll: 150 ms"
    end

    test "says when the press was warm", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      log =
        capture_log([level: :info], fn ->
          view
          |> element("#talk-button")
          |> render_hook("hold_ended", %{
            "ended_by" => "pointerup",
            "hold_ms" => 1500,
            "lost_capture" => false,
            "mic_open_ms" => 0,
            "warm" => true,
            "post_roll_ms" => 150
          })
        end)

      assert log =~
               "hold ended by pointerup after 1500 ms, lost capture: false, mic open: 0 ms, warm: true, post roll: 150 ms"
    end

    test "says when the hold ended before the mic was live", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      log =
        capture_log([level: :info], fn ->
          view
          |> element("#talk-button")
          |> render_hook("hold_ended", %{
            "ended_by" => "pointerup",
            "hold_ms" => 60,
            "warm" => false,
            "post_roll_ms" => 0
          })
        end)

      assert log =~
               "hold ended by pointerup after 60 ms, lost capture: false, mic open: none, warm: false, post roll: 0 ms"
    end

    test "with an unknown ending, a bad length, warm or post roll is ignored", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")

      good = %{"ended_by" => "pointerup", "hold_ms" => 10, "warm" => true, "post_roll_ms" => 0}

      log =
        capture_log([level: :info], fn ->
          for bad <- [
                %{"ended_by" => "<script>"},
                %{"hold_ms" => -1},
                %{"hold_ms" => "5000"},
                %{"warm" => "true"},
                %{"post_roll_ms" => -5},
                %{"post_roll_ms" => "150"}
              ] do
            view |> element("#talk-button") |> render_hook("hold_ended", Map.merge(good, bad))
          end

          for params <- [Map.delete(good, "warm"), Map.delete(good, "post_roll_ms"), %{}] do
            view |> element("#talk-button") |> render_hook("hold_ended", params)
          end
        end)

      refute log =~ "hold ended"
      assert has_element?(view, "#talk-screen[data-state='idle']")
    end
  end

  test "the Talk button's own state is never set from the server's moment", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")
    view |> element("#talk-button") |> render_hook("talk_state", %{"state" => "recording"})

    assert has_element?(view, "#talk-screen[data-state='recording']")
    # Ignored elements still merge server data attributes (LiveView DOM patching), so the
    # button only ever carries the static mount value and the hook restores its own.
    assert has_element?(view, "#talk-button[data-state='idle'][phx-update='ignore']")
  end

  test "the chat shows only the last 3 exchanges, the latest as now", %{conn: conn, guest: guest} do
    for n <- 1..5,
        do: {:ok, _} = Turn.insert(%Turn{guest_id: guest, question: "Q#{n}", answer: "A#{n}"})

    {:ok, view, _html} = live(conn, ~p"/talk")
    html = render(view)

    assert has_element?(view, "#turns #conversation")
    assert count(html, "#conversation .turn") == 3
    assert texts(html, "#conversation .turn .question") == ~w(Q3 Q4 Q5)
    assert count(html, "#conversation .turn.now") == 1
    assert has_element?(view, "#conversation .turn.now .answer", "A5")
  end

  test "a nothing heard Question reads as a friendly line", %{conn: conn, guest: guest} do
    {:ok, _} =
      Turn.insert(%Turn{
        guest_id: guest,
        question: "(nothing heard)",
        answer: "I did not catch that."
      })

    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(
             view,
             "#conversation .turn .question.nothing-heard",
             "Maya did not hear anything that time"
           )

    refute has_element?(view, "#conversation", "(nothing heard)")
  end

  test "the Talk button has a hidden mic, a hint and a label per moment", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-button svg[aria-hidden='true']")
    assert has_element?(view, "#talk-button #talk-hint")

    for {show, label} <- [
          {"idle", "Hold to talk"},
          {"recording", "Release to send"},
          {"uploading waiting", "One sec…"},
          {"speaking", "Hold to cut in"}
        ],
        do: assert(has_element?(view, "#talk-button .talk-label [data-show='#{show}']", label))

    assert has_element?(view, "#start-fresh-button")
  end

  test "the Talk button starts idle and is bound to the Talk hook", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    assert has_element?(view, "#talk-button[data-state='idle'][phx-hook='TalkHook']")
    assert has_element?(view, "#talk-button[data-sample-rate='24000']")
    assert has_element?(view, "#talk-button[data-post-roll-ms='150']")
    refute has_element?(view, "#conversation .turn")
  end

  test "the screen shows the session guest's turns and no other guest's", %{
    conn: conn,
    guest: guest
  } do
    {:ok, _} = Turn.insert(%Turn{guest_id: guest, question: "Mine", answer: "Yours"})
    {:ok, _} = Turn.insert(%Turn{guest_id: "someone-else", question: "Theirs", answer: "No"})

    {:ok, view, _html} = live(conn, ~p"/talk")

    assert view |> element("#conversation .turn .question") |> render() =~ "Mine"
    refute has_element?(view, "#conversation .turn .question", "Theirs")
  end

  test "a session with no guest reloads the page so the pipeline gives it one" do
    # A fresh conn: the setup conn's test session already holds a guest.
    assert {:error, {:redirect, %{to: "/talk"}}} =
             live_isolated(build_conn(), MayaWeb.TalkLive, session: %{})
  end

  test "Start fresh asks first, then offers a form that posts to /fresh", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")
    refute has_element?(view, "#start-fresh-confirm")

    view |> element("#start-fresh-button") |> render_click()
    assert has_element?(view, "#start-fresh-confirm[action='/fresh'][method='post']")
    assert has_element?(view, "#start-fresh-confirm input[name='_csrf_token']")
    assert has_element?(view, "#start-fresh-confirm #start-fresh-yes[type='submit']")

    view |> element("#keep-talking") |> render_click()
    refute has_element?(view, "#start-fresh-confirm")
    assert has_element?(view, "#start-fresh-button")
  end

  test "a hold streams its audio: no upload form, one Question per hold", %{
    conn: conn,
    guest: guest
  } do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")
    refute has_element?(view, "#question-form")

    ask(view)
    assert_push_event(view, "audio_done", %{})
    # A late second end for the same hold is ignored.
    view |> element("#talk-button") |> render_hook("stream_end", %{})

    _ = Maya.Conversation.turns(guest)
    assert [%Turn{question: "Where is Ralts", stt_source: "batch"}] = Turn.recent(guest)
  end

  test "a hold's turn id comes back on its audio and audio_done (#96)", %{conn: conn} do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")

    ask(view, %{"turn" => 1_763_500_000_000})
    assert_push_event(view, "audio", %{turn: 1_763_500_000_000})
    assert_push_event(view, "audio_done", %{turn: 1_763_500_000_000})

    # The client's value is untrusted: anything but an integer becomes no turn id.
    ask(view, %{"turn" => "<script>"})
    assert_push_event(view, "audio_done", %{turn: nil})
  end

  test "a playback stall cuts the turn and shows voice down (#96)", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")
    button = element(view, "#talk-button")

    log =
      capture_log(fn ->
        render_hook(button, "playback_stalled", %{"context" => "interrupted"})
      end)

    assert log =~ "[warning] playback stalled, context: interrupted"
    assert view |> element("#voice-down") |> render() =~ "voice is down"

    log = capture_log(fn -> render_hook(button, "playback_stalled", %{"context" => "<b>"}) end)
    assert log =~ "playback stalled, context: unknown"
  end

  test "partial text shows in the live bubble, then the final Question is pending", %{conn: conn} do
    {:ok, view, _html} = live(conn, ~p"/talk")

    send(view.pid, {:conversation, {:partial, "where do I catch"}})
    assert view |> element("#live-question") |> render() =~ "where do I catch"

    send(view.pid, {:conversation, {:question, "where do I catch Ralts?"}})
    refute has_element?(view, "#live-question")
    assert view |> element("#pending-question") |> render() =~ "where do I catch Ralts?"
    assert has_element?(view, "#conversation[aria-live=polite] #pending-question")

    send(view.pid, {:conversation, {:turns, []}})
    refute has_element?(view, "#pending-question")
  end

  test "one hold is transcribed, answered, spoken and shown", %{conn: conn, guest: guest} do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")

    ask(view)

    assert_push_event(view, "heard", %{})
    assert_push_event(view, "audio", %{pcm: pcm})
    assert Base.decode64!(pcm) == <<1, 2>>
    assert_push_event(view, "audio_done", %{})

    assert view |> element("#conversation .turn .question") |> render() =~ "Where is Ralts"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
    assert has_element?(view, "#trainer-card #badge-case")
    refute has_element?(view, "#poke-facts")
    # A call returns only after the Conversation stored the turn.
    _ = Maya.Conversation.turns(guest)
    assert [%Turn{question: "Where is Ralts"}] = Turn.recent(guest)
  end

  # The agent logs the Event the Question names, then answers with the tool's line.
  defp log_events do
    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)
      last = List.last(Jason.decode!(body)["messages"])

      message =
        case {last["role"], last["content"]} do
          {"tool", content} ->
            answer = %{answer: content, used_tool_calls: [last["tool_call_id"]]}
            %{"role" => "assistant", "content" => Jason.encode!(answer)}

          {"user", question} ->
            %{"role" => "assistant", "content" => nil, "tool_calls" => [log_call(question)]}
        end

      Req.Test.json(conn, %{"choices" => [%{"message" => message}]})
    end)
  end

  defp log_call(question) do
    args =
      cond do
        question =~ "badge" ->
          %{"kind" => "badge_earned", "details" => %{"leader" => "Roxanne"}}

        question =~ "caught" ->
          %{"kind" => "caught", "details" => %{"species" => "ralts", "level" => 5}}

        question =~ "Dewford" ->
          %{"kind" => "moved", "details" => %{"location" => "Dewford Town"}}

        true ->
          %{"kind" => "undo"}
      end

    %{
      "id" => "call_#{System.unique_integer([:positive])}",
      "type" => "function",
      "function" => %{"name" => "log_event", "arguments" => Jason.encode!(args)}
    }
  end

  defp ask_and_hear(view, question) do
    stub(text(question), &speak/1)
    ask(view)
    assert_push_event(view, "audio_done", %{})
  end

  test "an Event in a turn updates the trainer card without a reload", %{conn: conn} do
    log_events()
    {:ok, view, _html} = live(conn, ~p"/talk")
    assert has_element?(view, "#badge-count", "0 of 8 badges")

    ask_and_hear(view, "I just earned Roxanne's badge")
    assert has_element?(view, "#badge-count", "1 of 8 badges")
    assert has_element?(view, "#next-gym", "Next gym: Brawly")

    ask_and_hear(view, "I sailed to Dewford")
    assert has_element?(view, "#location", "Dewford Town")

    ask_and_hear(view, "I caught a Ralts at level 5")
    assert has_element?(view, "#team .mon", "Ralts Lv 5")

    ask_and_hear(view, "undo that")
    refute has_element?(view, "#team .mon", "Ralts")
    assert has_element?(view, "#location", "Dewford Town")

    ask_and_hear(view, "undo that too")
    assert has_element?(view, "#location", "Littleroot Town")

    ask_and_hear(view, "and undo the last one")
    assert has_element?(view, "#badge-count", "0 of 8 badges")
    assert has_element?(view, "#next-gym", "Next gym: Roxanne")
  end

  test "a cut after the agent logged an Event still updates the card", %{conn: conn, guest: guest} do
    me = self()

    Req.Test.stub(Maya.OpenRouter, fn conn ->
      {:ok, body, conn} = Plug.Conn.read_body(conn)

      case List.last(Jason.decode!(body)["messages"]) do
        %{"role" => "tool"} ->
          send(me, :logged)
          Process.sleep(:infinity)

        %{"content" => question} ->
          message = %{
            "role" => "assistant",
            "content" => nil,
            "tool_calls" => [log_call(question)]
          }

          Req.Test.json(conn, %{"choices" => [%{"message" => message}]})
      end
    end)

    stub(text("I just earned Roxanne's badge"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")
    ask(view)
    assert_receive :logged

    view |> element("#talk-button") |> render_hook("barge_in", %{})
    _ = Maya.Conversation.turns(guest)
    assert has_element?(view, "#badge-count", "1 of 8 badges")
  end

  test "playback timings are stored, junk values are dropped", %{conn: conn, guest: guest} do
    stub(text("Where is Ralts"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")
    ask(view)
    assert_push_event(view, "audio_done", %{})
    _ = render(view)

    view
    |> element("#talk-button")
    |> render_hook("playback_started", %{"mic_release_ms" => 180, "playback_start_ms" => "soon"})

    _ = Maya.Conversation.turns(guest)
    assert [%Turn{mic_release_ms: 180, playback_start_ms: nil}] = Turn.recent(guest)
  end

  test "barge-in keeps the Answer as text and marks it cut", %{conn: conn, guest: guest} do
    me = self()

    stub(text("Where is Ralts"), fn conn ->
      send(me, :speaking)
      Process.sleep(:infinity)
      conn
    end)

    {:ok, view, _html} = live(conn, ~p"/talk")
    ask(view)
    assert_receive :speaking

    view |> element("#talk-button") |> render_hook("barge_in", %{})

    _ = Maya.Conversation.turns(guest)
    assert view |> element("#conversation .turn .cut") |> render() =~ "cut short"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
  end

  test "TTS down shows the Answer with a voice is down note", %{conn: conn} do
    stub(text("Where is Ralts"), &Plug.Conn.send_resp(&1, 503, "down"))
    {:ok, view, _html} = live(conn, ~p"/talk")

    ask(view)

    assert_push_event(view, "voice_down", %{})
    assert view |> element("#conversation .turn .voice-down") |> render() =~ "voice is down"
    assert view |> element("#conversation .turn .answer") |> render() =~ "Where is Ralts"
    refute has_element?(view, "#voice-down")
  end

  test "STT down shows the voice is down note on its own", %{conn: conn} do
    stub(&Plug.Conn.send_resp(&1, 500, "down"), &speak/1)
    {:ok, view, _html} = live(conn, ~p"/talk")

    ask(view)

    assert_push_event(view, "voice_down", %{})
    assert view |> element("#voice-down") |> render() =~ "voice is down"
    refute has_element?(view, "#conversation .turn")
  end

  # #192: Postgres down or paused when the screen opens; the shared sandbox is switched off as in #191.
  test "/talk with the database down shows the notes line, never a 500 or a crash", %{conn: conn} do
    Ecto.Adapters.SQL.Sandbox.mode(Maya.Repo, :manual)

    log =
      capture_log(fn ->
        dead = get(conn, ~p"/talk")
        assert html_response(dead, 200) =~ "Maya can't reach her notes right now."

        {:ok, view, _html} = live(conn, ~p"/talk")

        assert view |> element("#notes-down") |> render() =~
                 "Maya can&#39;t reach her notes right now. Try again in a minute."

        assert has_element?(view, "#notes-down a[href='/talk']", "Try again")
        refute has_element?(view, "#talk-button")
      end)

    assert log =~ "[warning] talk mount failed: DBConnection.OwnershipError"
  end

  describe "countdown beside the agent, tap to edit and typed Questions (#95)" do
    setup %{guest: guest} do
      voice = Application.fetch_env!(:maya, :voice)
      Application.put_env(:maya, :voice, Keyword.put(voice, :confirm_ms, 2_000))
      on_exit(fn -> Application.put_env(:maya, :voice, voice) end)

      # Echoes the Question; one with "rawls" is slow, so the tap lands while it is in flight.
      me = self()

      Req.Test.stub(Maya.OpenRouter, fn conn ->
        {:ok, body, conn} = Plug.Conn.read_body(conn)
        question = List.last(Jason.decode!(body)["messages"])["content"]
        send(me, {:agent_asked, question})
        if question =~ "rawls", do: Process.sleep(500)
        answer = Jason.encode!(%{answer: question, used_tool_calls: []})

        Req.Test.json(conn, %{
          "choices" => [%{"message" => %{"role" => "assistant", "content" => answer}}]
        })
      end)

      Maya.Conversation.subscribe(guest)
      :ok
    end

    test "the countdown shows the seconds as text while the agent already has the Question", %{
      conn: conn,
      guest: guest
    } do
      {:ok, view, _html} = live(conn, ~p"/talk")
      send(view.pid, {:conversation, {:pending, "where do I catch Ralts?", 2_000}})

      assert view |> element("#pending-question #edit-input") |> render() =~
               "where do I catch Ralts?"

      assert view |> element("#pending-countdown") |> render() =~ "Tap to edit, 2 s"
      assert has_element?(view, "#edit-input[phx-focus=edit_question]")
      refute has_element?(view, "#edit-input[readonly]")
      assert has_element?(view, "label[for=edit-input]")
      assert has_element?(view, "#conversation[aria-live=polite] #pending-countdown")

      stub(text("where do I catch Ralts?"), &speak/1)
      ask(view)
      assert_receive {:conversation, {:pending, "where do I catch Ralts?", 2_000}}
      assert_receive {:agent_asked, "where do I catch Ralts?"}, 1_000
      assert_push_event(view, "audio_done", %{}, 1_500)

      assert view |> element("#conversation .turn .question") |> render() =~ "Ralts"
      refute has_element?(view, "#pending-question")
      _ = Maya.Conversation.turns(guest)
      assert [%Turn{confirm_ms: ms, typed: false}] = Turn.recent(guest)
      assert ms < 100
    end

    test "after the countdown the text turns readonly in place", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")
      send(view.pid, {:conversation, {:pending, "where do I catch Ralts?", 2_000}})
      send(view.pid, {:conversation, {:question, "where do I catch Ralts?"}})
      assert has_element?(view, "#pending-question #edit-input[readonly]")
      refute has_element?(view, "#edit-input[phx-focus]")
      refute has_element?(view, "#pending-countdown")
    end

    test "a tap on the text drops the in-flight Answer, Send asks the edited text", %{
      conn: conn,
      guest: guest
    } do
      stub(text("where do I catch rawls"), &speak/1)
      {:ok, view, _html} = live(conn, ~p"/talk")
      ask(view)
      assert_receive {:conversation, {:pending, _text, 2_000}}
      assert_receive {:agent_asked, "where do I catch rawls"}

      view |> element("#edit-input") |> render_focus()
      assert_push_event(view, "question_editing", %{})
      assert has_element?(view, "#edit-form #edit-send.tap-44")
      assert has_element?(view, "#edit-form #edit-cancel.tap-44")
      refute has_element?(view, "#pending-countdown")

      view |> form("#edit-form", %{text: "  "}) |> render_submit()
      assert view |> element("#edit-input-error") |> render() =~ "Use 1 to 300 characters"
      view |> form("#edit-form", %{text: String.duplicate("a", 301)}) |> render_submit()
      assert has_element?(view, "#edit-send")
      refute_received {:agent_asked, _}

      view |> form("#edit-form", %{text: " where do I catch Ralts? "}) |> render_submit()
      assert_push_event(view, "asked", %{turn: nil, typed: false})
      refute has_element?(view, "#edit-send")
      assert_receive {:agent_asked, "where do I catch Ralts?"}
      assert_push_event(view, "audio_done", %{}, 1_000)
      _ = Maya.Conversation.turns(guest)
      assert [%Turn{question: "where do I catch Ralts?"}] = Turn.recent(guest)
    end

    test "Cancel speaks nothing and stores no turn", %{conn: conn, guest: guest} do
      stub(text("where do I catch rawls"), &speak/1)
      {:ok, view, _html} = live(conn, ~p"/talk")
      ask(view)
      assert_receive {:conversation, {:pending, _text, 2_000}}

      view |> element("#edit-input") |> render_focus()
      view |> element("#edit-cancel") |> render_click()
      assert_push_event(view, "question_cancelled", %{})
      refute has_element?(view, "#pending-question")
      refute_push_event(view, "audio", %{}, 700)
      assert Maya.Conversation.turns(guest) == []
      assert Turn.recent(guest) == []
    end

    test "a hold during the countdown drops the pending Question", %{conn: conn, guest: guest} do
      {:ok, texts} =
        Elixir.Agent.start_link(fn -> ["where do I catch rawls", "is Zigzagoon on route 101"] end)

      stub(
        fn conn ->
          Req.Test.json(conn, %{"text" => Elixir.Agent.get_and_update(texts, &{hd(&1), tl(&1)})})
        end,
        &speak/1
      )

      {:ok, view, _html} = live(conn, ~p"/talk")
      ask(view)
      assert_receive {:conversation, {:pending, "where do I catch rawls", 2_000}}
      ask(view)
      assert_receive {:conversation, {:pending, "is Zigzagoon on route 101", 2_000}}
      assert view |> element("#pending-question") |> render() =~ "Zigzagoon"

      assert_push_event(view, "audio_done", %{}, 1_500)
      _ = Maya.Conversation.turns(guest)
      assert [%Turn{question: "is Zigzagoon on route 101"}] = Turn.recent(guest)
    end

    test "a typed Question skips STT and the countdown and is stored as typed", %{
      conn: conn,
      guest: guest
    } do
      me = self()

      stub(
        fn conn ->
          send(me, :stt_called)
          Req.Test.json(conn, %{"text" => "nope"})
        end,
        &speak/1
      )

      {:ok, view, _html} = live(conn, ~p"/talk")
      # The tap focuses the always rendered input itself (iOS keyboard), then tells the server.
      assert has_element?(view, "#type-button.tap-44[aria-label='Type a Question']")
      assert view |> element("#type-button") |> render() =~ "#type-input"
      assert has_element?(view, "#type-form:not(.open) #type-input")

      view |> element("#type-button") |> render_click()
      assert has_element?(view, "#type-form.open label[for=type-input]")
      view |> form("#type-form", %{text: String.duplicate("a", 301)}) |> render_submit()
      assert view |> element("#type-input-error") |> render() =~ "Use 1 to 300 characters"
      refute_received {:agent_asked, _}

      view |> form("#type-form", %{text: "How do I earn Roxanne's badge?"}) |> render_submit()
      assert_push_event(view, "asked", %{turn: turn, typed: true})
      assert is_integer(turn)
      refute has_element?(view, "#type-form.open")
      assert_receive {:agent_asked, "How do I earn Roxanne's badge?"}
      assert_push_event(view, "audio", %{turn: ^turn})
      assert_push_event(view, "audio_done", %{turn: ^turn})
      refute_received {:conversation, {:pending, _, _}}

      assert view |> element("#conversation .turn .question") |> render() =~ "Roxanne"
      _ = Maya.Conversation.turns(guest)

      assert [%Turn{typed: true, stt_ms: nil, mic_release_ms: nil, confirm_ms: nil}] =
               Turn.recent(guest)

      refute_received :stt_called
    end

    test "Cancel closes the type form", %{conn: conn} do
      {:ok, view, _html} = live(conn, ~p"/talk")
      view |> element("#type-button") |> render_click()
      view |> element("#type-cancel") |> render_click()
      refute has_element?(view, "#type-form.open")
    end

    test "targets are 44 px, fields 16 px and the countdown bar stops under reduced motion" do
      css = File.read!("assets/css/app.css")
      assert css =~ ".tap-44 { min-width: 44px; min-height: 44px; }"
      assert css =~ ~r/\.pending-text \{[^}]*font-size: var\(--maya-text-base\)/
      [_, reduced] = String.split(css, "@media (prefers-reduced-motion: reduce) {", parts: 2)
      assert reduced =~ ~r/::after \{ animation: none !important/
    end
  end
end
