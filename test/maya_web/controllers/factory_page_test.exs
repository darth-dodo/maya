defmodule MayaWeb.FactoryPageTest do
  # No database: the factory page reads none, so this runs without the SQL sandbox.
  use ExUnit.Case, async: true

  import Phoenix.ConnTest
  use MayaWeb, :verified_routes

  @endpoint MayaWeb.Endpoint

  # Scenarios from openspec/specs/factory-page/spec.md (the public page at /factory).

  @later_leaders ~w(Brawly Wattson Flannery Norman Winona Tate Liza Juan)
  @experiments_md Path.expand("../../../docs/factory/experiments.md", __DIR__)
  @ci_yml Path.expand("../../../.github/workflows/ci.yml", __DIR__)

  defp factory, do: build_conn() |> get(~p"/factory") |> html_response(200)

  defp query(html, selector), do: html |> LazyHTML.from_document() |> LazyHTML.query(selector)
  defp text(node), do: node |> LazyHTML.text() |> String.replace(~r/\s+/, " ") |> String.trim()
  defp text_of(html, selector), do: html |> query(selector) |> text()
  defp count(html, selector), do: html |> query(selector) |> Enum.count()
  defp attrs(html, selector, name), do: html |> query(selector) |> LazyHTML.attribute(name)
  defp numbers(text), do: ~r/\d+(?:\.\d+)?/ |> Regex.scan(text) |> List.flatten()

  # The experiments table rows in docs/factory/experiments.md, as lists of trimmed cells.
  defp experiment_rows do
    @experiments_md
    |> File.read!()
    |> String.split("\n")
    |> Enum.filter(&String.starts_with?(&1, "| E"))
    |> Enum.map(fn line ->
      line |> String.trim("|") |> String.split("|") |> Enum.map(&String.trim/1)
    end)
  end

  defp backfill_section do
    [_, section] = @experiments_md |> File.read!() |> String.split("## Review reward backfill")
    section
  end

  describe "public factory page" do
    test "visitor without a login opens the factory page" do
      html = factory()

      assert count(html, "h1") == 1
      assert text_of(html, "h1#factory-heading") != ""
      assert text_of(html, "title") == "Maya factory"
      assert count(html, "[data-phx-main]") == 0
      assert "/" in attrs(html, "#site-footer a", "href")
    end

    test "indexable: no noindex and robots.txt allows it" do
      robots = attrs(factory(), "meta[name='robots']", "content")
      refute Enum.any?(robots, &(&1 =~ "noindex"))

      body = build_conn() |> get("/robots.txt") |> response(200)
      refute body =~ ~r/^Disallow: \/factory\s*$/m
    end
  end

  test "four stations in order" do
    names =
      factory()
      |> query("#stations .station .station-name")
      |> Enum.map(&text/1)

    assert names == ["Plan", "Build", "Test", "Review"]
    assert count(factory(), "#stations .station") == 4
  end

  describe "independent gates" do
    test "three gates, each with text" do
      html = factory()

      for id <- ~w(#gate-ci #gate-probe #gate-spoiler),
          do: assert(text_of(html, "#gates #{id}") != "", id)
    end

    test "spoiler gate wording stays honest while CI has no spoiler job" do
      spoiler_job? = Regex.match?(~r/^  [\w-]*spoiler[\w-]*:\s*$/m, File.read!(@ci_yml))

      if spoiler_job? do
        refute text_of(factory(), "#gate-spoiler") =~ "planned"
      else
        assert text_of(factory(), "#gate-spoiler") =~ "planned"
      end
    end
  end

  describe "flywheel" do
    test "experiment rows match docs/factory/experiments.md" do
      html = factory()
      rows = experiment_rows()
      assert Enum.map(rows, &hd/1) == ~w(E1 E2 E3)
      assert count(html, "#experiments tbody tr") == length(rows)

      for [id, _change, metric, baseline, target, status, _prs] <- rows do
        row = "#experiments tbody tr#experiment-#{String.downcase(id)}"
        assert text_of(html, "#{row} .exp-id") == id
        assert text_of(html, "#{row} .exp-metric") == metric
        assert text_of(html, "#{row} .exp-baseline") == baseline
        assert text_of(html, "#{row} .exp-target") == target
        assert text_of(html, "#{row} .exp-status") == status
      end

      table_numbers = rows |> List.flatten() |> Enum.join(" ") |> numbers()

      for n <- numbers(text_of(html, "#experiments")),
          do: assert(n in table_numbers, "#{n} is not in docs/factory/experiments.md")
    end

    test "review reward backfill shown, honestly" do
      reward = text_of(factory(), "#review-reward")

      assert reward =~ "2 of 3 escaped defects"
      assert backfill_section() =~ "2 of 3 escaped defects"
      assert reward =~ "low"

      section_numbers = numbers(backfill_section())

      for n <- numbers(reward),
          do: assert(n in section_numbers, "#{n} is not in the Review reward backfill section")
    end

    test "flywheel holds the experiments and the review reward, retros every 5" do
      html = factory()

      assert count(html, "#flywheel #experiments") == 1
      assert count(html, "#flywheel #review-reward") == 1
      flywheel = text_of(html, "#flywheel")
      assert flywheel =~ "retro"
      assert flywheel =~ ~r/\b5\b/
    end
  end

  describe "source links and copy" do
    test "links to FACTORY.md and the explainer, only own assets" do
      html = factory()
      hrefs = attrs(html, "a", "href")

      for href <- [
            "https://github.com/darth-dodo/maya/blob/main/FACTORY.md",
            "https://github.com/darth-dodo/maya/blob/main/docs/elixir-phoenix-in-5-minutes.md"
          ],
          do: assert(href in hrefs, href)

      for ref <- attrs(html, "[src]", "src") ++ attrs(html, "link[rel=stylesheet]", "href"),
          do: assert(String.starts_with?(ref, "/") and not String.starts_with?(ref, "//"), ref)
    end

    test "inclusive and spoiler-free copy" do
      body = text_of(factory(), "body")

      refute body =~ ~r/beat|defeat/i
      for name <- @later_leaders, do: refute(body =~ name, "#{name} on the factory page")
    end
  end
end
