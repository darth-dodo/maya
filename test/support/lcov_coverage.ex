defmodule Maya.LcovCoverage do
  @moduledoc """
  `test_coverage` tool for `mix test --cover`: runs Elixir's built-in tool (per-module
  table and threshold) and first writes `cover/lcov.info`, the format Codecov reads.
  No dependency: the line counts come straight from Erlang's `:cover`.
  """

  # :cover ships in the :tools app, which Mix loads only when coverage runs.
  @compile {:no_warn_undefined, :cover}

  def start(compile_path, opts) do
    finish = Mix.Tasks.Test.Coverage.start(compile_path, opts)

    fn ->
      output = Keyword.get(opts, :output, "cover")
      File.mkdir_p!(output)
      ignored = Keyword.get(opts, :ignore_modules, [])

      lcov =
        for mod <- Enum.sort(:cover.modules()), not ignored?(mod, ignored), into: "" do
          {:ok, lines} = :cover.analyse(mod, :calls, :line)
          record(Path.relative_to_cwd(to_string(mod.module_info(:compile)[:source])), lines)
        end

      File.write!(Path.join(output, "lcov.info"), lcov)
      finish.()
    end
  end

  @doc "One LCOV record for a source file from `:cover` `{{module, line}, calls}` pairs."
  def record(path, lines) do
    hits = for {{_mod, line}, calls} <- lines, line > 0, do: {line, calls}
    hit = Enum.count(hits, fn {_, calls} -> calls > 0 end)
    da = Enum.map_join(hits, fn {line, calls} -> "DA:#{line},#{calls}\n" end)
    "TN:\nSF:#{path}\n#{da}LF:#{length(hits)}\nLH:#{hit}\nend_of_record\n"
  end

  defp ignored?(mod, ignored) do
    Enum.any?(ignored, fn
      %Regex{} = re -> Regex.match?(re, inspect(mod))
      other -> other == mod
    end)
  end
end
