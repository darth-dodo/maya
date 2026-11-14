defmodule Maya.LcovCoverageTest do
  use ExUnit.Case, async: true

  test "record lists each executable line with its calls and the hit totals" do
    lines = [{{Foo, 0}, 1}, {{Foo, 3}, 2}, {{Foo, 5}, 0}]

    assert Maya.LcovCoverage.record("lib/foo.ex", lines) ==
             "TN:\nSF:lib/foo.ex\nDA:3,2\nDA:5,0\nLF:2\nLH:1\nend_of_record\n"
  end
end
