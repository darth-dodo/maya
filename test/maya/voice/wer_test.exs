defmodule Maya.Voice.WERTest do
  use ExUnit.Case, async: true

  alias Maya.Voice.WER

  test "the spec example: one wrong word in five and the name missed" do
    assert WER.wer("Where do I catch Ralts?", "where do I catch rails") == 0.2
    assert WER.name_accuracy(["Ralts"], "where do I catch rails") == 0.0
  end

  test "case and punctuation do not count as errors" do
    assert WER.wer("How do I earn Roxanne's badge?", "how do i earn roxannes badge") == 0.0
    assert WER.name_accuracy(["Roxanne"], "How do I earn Roxanne's badge?") == 1.0
  end

  test "insertions and deletions count as edits over the reference words" do
    assert WER.edits("is zigzagoon on route 101", "is zigzagoon on route") == {1, 5}
    assert WER.edits("what type is nosepass", "what what type is nosepass") == {1, 4}
  end

  test "empty transcripts and empty references" do
    assert WER.wer("Where is Ralts?", "") == 1.0
    assert WER.wer("", "") == 0.0
    assert WER.name_accuracy([], "anything") == 1.0
  end
end
