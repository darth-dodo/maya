# Regenerates priv/data/english_guard.txt: every English word, or its s/es/ed/ing form, that
# Maya.Voice.Vocabulary.correct/2 would otherwise snap to a known name (Issue #68).
# Source: Webster's Second (public domain), shipped on macOS as /usr/share/dict/words.
# Run when game names or the threshold change:
#   mix run --no-start scripts/english_guard.exs [/usr/share/dict/words]

alias Maya.Voice.Vocabulary

dict = List.first(System.argv()) || "/usr/share/dict/words"
read = &(Path.join("priv/data", &1) |> File.read!() |> Jason.decode!())

names = %{
  species: Enum.map(read.("species.json"), & &1["name"]),
  locations: Enum.map(read.("locations.json"), &%{name: &1["name"], badges_required: &1["badges_required"]})
}

terms = Vocabulary.bias_terms(%{badges: [], team: []}, names)
keys = for t <- terms, w <- String.split(t), uniq: true, do: String.downcase(w)
by_first = Enum.group_by(keys, &String.first/1)

words =
  dict
  |> File.read!()
  |> String.split()
  |> Enum.filter(&(&1 =~ ~r/^[a-z]{3,}$/))

guard =
  words
  |> Task.async_stream(
    fn w ->
      for f <- [w, w <> "s", w <> "es", w <> "ed", w <> "ing"],
          f not in keys,
          Vocabulary.near(f, by_first[String.first(f)] || []),
          do: f
    end,
    ordered: false
  )
  |> Enum.flat_map(fn {:ok, found} -> found end)
  |> Enum.uniq()
  |> Enum.sort()

File.write!("priv/data/english_guard.txt", Enum.join(guard, "\n") <> "\n")
IO.puts("#{length(guard)} guard words from #{length(words)} dictionary words")
