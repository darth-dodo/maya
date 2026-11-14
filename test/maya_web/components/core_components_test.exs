defmodule MayaWeb.CoreComponentsTest do
  use ExUnit.Case, async: true

  import Phoenix.Component, only: [sigil_H: 2, to_form: 2]
  import Phoenix.LiveViewTest
  import MayaWeb.CoreComponents

  alias Phoenix.LiveView.JS
  alias Phoenix.LiveView.LiveStream

  defp doc(rendered), do: rendered |> rendered_to_string() |> LazyHTML.from_fragment()

  defp text(doc, selector),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.text() |> String.trim()

  defp attribute(doc, selector, name),
    do: doc |> LazyHTML.query(selector) |> LazyHTML.attribute(name)

  defp count(doc, selector), do: doc |> LazyHTML.query(selector) |> Enum.count()

  describe "flash" do
    test "shows the message for its kind from the flash map, with a title" do
      assigns = %{flash: %{"error" => "Mic blocked"}}

      html =
        doc(~H"""
        <.flash kind={:error} title="Oops" flash={@flash} />
        """)

      assert text(html, "#flash-error .font-semibold") == "Oops"
      assert text(html, "#flash-error") =~ "Mic blocked"
      assert count(html, "#flash-error .alert-error .hero-exclamation-circle") == 1
    end

    test "renders an inner block as an info toast with its own id" do
      assigns = %{}

      html =
        doc(~H"""
        <.flash id="hi" kind={:info}>Welcome back</.flash>
        """)

      assert text(html, "#hi .alert-info") =~ "Welcome back"
      assert count(html, "#hi .hero-information-circle") == 1
    end

    test "renders nothing when there is no message" do
      assigns = %{}

      html =
        doc(~H"""
        <.flash kind={:info} flash={%{}} />
        """)

      assert count(html, "[role=alert]") == 0
    end
  end

  describe "button" do
    test "is a soft primary button by default and a solid one for the primary variant" do
      assigns = %{}

      html =
        doc(~H"""
        <.button id="soft">Go</.button>
        <.button id="solid" variant="primary">Go</.button>
        """)

      assert attribute(html, "button#soft", "class") == ["btn btn-primary btn-soft"]
      assert attribute(html, "button#solid", "class") == ["btn btn-primary"]
    end

    test "is a link when given a navigation target" do
      assigns = %{}

      html =
        doc(~H"""
        <.button id="home" navigate="/">Home</.button>
        """)

      assert attribute(html, "a#home", "href") == ["/"]
      assert text(html, "a#home") == "Home"
    end
  end

  describe "input" do
    test "takes its name, id, value and errors from a used form field" do
      form = to_form(%{"name" => "Mudkip"}, as: :pokemon, errors: [name: {"is too short", []}])
      assigns = %{field: form[:name]}

      html =
        doc(~H"""
        <.input field={@field} label="Name" />
        """)

      assert attribute(html, "input#pokemon_name", "name") == ["pokemon[name]"]
      assert attribute(html, "input#pokemon_name", "value") == ["Mudkip"]
      assert attribute(html, "input#pokemon_name", "class") == ["w-full input input-error"]
      assert text(html, ".label") == "Name"
      assert text(html, "p.text-error") == "is too short"
    end

    test "hides errors on a field the player has not used yet" do
      params = %{"_unused_name" => "", "name" => ""}
      form = to_form(params, as: :pokemon, errors: [name: {"can't be blank", []}])
      assigns = %{field: form[:name]}

      html =
        doc(~H"""
        <.input field={@field} />
        """)

      assert count(html, "p.text-error") == 0
    end

    test "appends [] to the name of a multiple select field" do
      form = to_form(%{"team" => ["mudkip"]}, as: :p)
      assigns = %{field: form[:team]}

      html =
        doc(~H"""
        <.input field={@field} type="select" multiple options={~w(mudkip ralts)} />
        """)

      assert attribute(html, "select", "name") == ["p[team][]"]
      assert attribute(html, "option[selected]", "value") == ["mudkip"]
    end

    test "renders hidden, checkbox, select and textarea types" do
      assigns = %{}

      html =
        doc(~H"""
        <.input type="hidden" id="h" name="h" value="1" />
        <.input type="checkbox" id="c" name="c" value="true" label="Hype" />
        <.input
          type="select"
          id="s"
          name="s"
          label="Lead"
          prompt="Pick"
          value="b"
          options={[A: "a", B: "b"]}
        />
        <.input type="textarea" id="t" name="t" label="Note" value="note" errors={~w(bad)} />
        """)

      assert attribute(html, "input#h", "type") == ["hidden"]
      assert attribute(html, "input#c", "checked") == [""]
      assert attribute(html, "input[type=hidden][name=c]", "value") == ["false"]
      assert text(html, "option[value='']") == "Pick"
      assert attribute(html, "#s option[selected]", "value") == ["b"]
      assert text(html, "textarea#t") == "note"
      assert attribute(html, "textarea#t", "class") == ["w-full textarea textarea-error"]
      assert text(html, "p.text-error") == "bad"
    end
  end

  test "header shows a subtitle and actions" do
    assigns = %{}

    html =
      doc(~H"""
      <.header>
        Team
        <:subtitle>Six max</:subtitle>
        <:actions><.button>Add</.button></:actions>
      </.header>
      """)

    assert text(html, "h1") == "Team"
    assert text(html, "p") == "Six max"
    assert text(html, "button") == "Add"
  end

  test "table renders a row per item with columns, row ids, clicks and actions" do
    assigns = %{rows: [%{id: 1, name: "Mudkip"}, %{id: 2, name: "Ralts"}]}

    html =
      doc(~H"""
      <.table id="team" rows={@rows} row_id={&"p-#{&1.id}"} row_click={&JS.push("pick", value: &1)}>
        <:col :let={p} label="Name">{p.name}</:col>
        <:action :let={p}>Pick {p.name}</:action>
      </.table>
      """)

    assert text(html, "thead th") =~ "Name"
    assert text(html, "#p-1 td") =~ "Mudkip"
    assert text(html, "#p-2 td.w-0") == "Pick Ralts"
    assert count(html, "#p-1 td[phx-click]") == 1
  end

  test "table takes row ids from a stream" do
    assigns = %{rows: LiveStream.new(:team, 0, [%{id: 7, name: "Mudkip"}], [])}

    html =
      doc(~H"""
      <.table id="team" rows={@rows} row_item={fn {_id, p} -> p end}>
        <:col :let={p} label="Name">{p.name}</:col>
      </.table>
      """)

    assert attribute(html, "tbody#team", "phx-update") == ["stream"]
    assert text(html, "#team-7") == "Mudkip"
  end

  test "list renders a titled row per item" do
    assigns = %{}

    html =
      doc(~H"""
      <.list>
        <:item title="Badges">0</:item>
      </.list>
      """)

    assert text(html, ".list-row .font-bold") == "Badges"
  end

  test "show and hide build transition commands for a selector" do
    assert [["show", %{to: "#x"}]] = targets(show("#x"))
    assert [["hide", %{to: "#x"}]] = targets(hide(%JS{}, "#x"))
  end

  defp targets(%JS{ops: ops}), do: for([op, args] <- ops, do: [op, Map.take(args, [:to])])

  test "translate_error interpolates and pluralises" do
    assert translate_error({"should be %{count} long", count: 3}) == "should be 3 long"
    assert translate_error({"is %{what}", what: "invalid"}) == "is invalid"
    assert translate_errors([name: {"is bad", []}, other: {"no", []}], :name) == ["is bad"]
  end
end
