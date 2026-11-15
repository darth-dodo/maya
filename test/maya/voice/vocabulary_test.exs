defmodule Maya.Voice.VocabularyTest do
  use ExUnit.Case, async: true

  alias Maya.Voice.Vocabulary

  # The committed game data, read straight from priv so these tests need no database.
  @names (fn ->
            read = &(Path.join("priv/data", &1) |> File.read!() |> Jason.decode!())

            %{
              species: Enum.map(read.("species.json"), & &1["name"]),
              locations:
                Enum.map(
                  read.("locations.json"),
                  &%{name: &1["name"], badges_required: &1["badges_required"]}
                )
            }
          end).()

  @fresh %{badges: [], team: [%{"species" => "mudkip", "level" => 5}]}

  defp terms(progress \\ @fresh), do: Vocabulary.bias_terms(progress, @names)

  describe "bias_terms/2" do
    test "puts Maya, Mudkip, the Team, the Next gym leader and horizon locations first" do
      progress = %{badges: [1], team: [%{"species" => "treecko"}, %{"species" => "ralts"}]}
      horizon = for l <- @names.locations, l.badges_required <= 1, do: l.name

      assert Enum.take(Vocabulary.bias_terms(progress, @names), 5 + length(horizon)) ==
               ["Maya", "Mudkip", "Treecko", "Ralts", "Brawly"] ++ horizon
    end

    test "holds every known species, gym leader, gym city and location once" do
      terms = terms()

      for t <-
            ["Ralts", "Torchic", "Zigzagoon", "Roxanne", "Juan", "Tate and Liza"] ++
              ["Rustboro City", "Sootopolis City", "Route 101"],
          do: assert(t in terms)

      assert terms == Enum.uniq(terms)
    end

    test "stays inside the cap and a few KB" do
      terms = terms()
      assert length(terms) <= Vocabulary.max_terms()
      assert terms |> Enum.map(&byte_size/1) |> Enum.sum() < 8_000
    end

    test "cuts from the end when capped" do
      many = %{@names | species: Enum.map(1..500, &"mon#{&1}")}
      terms = Vocabulary.bias_terms(@fresh, many)

      assert length(terms) == Vocabulary.max_terms()
      assert Enum.take(terms, 3) == ["Maya", "Mudkip", "Roxanne"]
      refute "Mon500" in terms
    end
  end

  describe "correct/2" do
    test "snaps real misses to the known name" do
      t = terms()

      assert Vocabulary.correct("where do I catch rawls", t) == "where do I catch Ralts"
      assert Vocabulary.correct("What is torch ick weak to?", t) == "What is Torchic weak to?"
      assert Vocabulary.correct("is zigzag goon on route 101", t) == "is Zigzagoon on route 101"

      assert Vocabulary.correct("How do I earn roxane's badge?", t) ==
               "How do I earn Roxanne's badge?"

      assert Vocabulary.correct("lead against nose pass", t) == "lead against Nosepass"
      assert Vocabulary.correct("the way to rustbro city", t) == "the way to Rustboro city"
    end

    test "keeps a name that is already right, with its possessive" do
      t = terms()

      assert Vocabulary.correct("How do I earn roxanne's badge?", t) ==
               "How do I earn roxanne's badge?"

      assert Vocabulary.correct("Where do I catch a Ralts?", t) == "Where do I catch a Ralts?"
    end

    test "never changes ordinary English words" do
      t = terms()

      for w <- ~w(rocks beach where badge route rails golden which electric around torch seed star
                  happy normal bloom explode spin beautiful horse swallow pitch nature),
          do: assert(Vocabulary.correct("the #{w} here", t) == "the #{w} here", w)
    end

    test "an empty transcript stays empty" do
      assert Vocabulary.correct("", terms()) == ""
    end
  end
end
