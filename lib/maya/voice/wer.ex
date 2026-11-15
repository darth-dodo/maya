defmodule Maya.Voice.WER do
  @moduledoc """
  Accuracy measures for the STT eval (`mix maya.stt_eval`, ADR-009). Word error rate is the
  word-level edit distance over the reference word count, after lowercasing and removing
  punctuation. Name accuracy is the share of expected names found exactly in the transcript.
  """

  @doc "Word error rate of `hypothesis` against `reference`."
  def wer(reference, hypothesis) do
    case edits(reference, hypothesis) do
      {0, 0} -> 0.0
      {edits, 0} -> edits * 1.0
      {edits, words} -> edits / words
    end
  end

  @doc "`{word edits, reference words}`, so totals can be summed over a set."
  def edits(reference, hypothesis) do
    ref = words(reference)
    {distance(ref, words(hypothesis)), length(ref)}
  end

  @doc "Share of `names` that appear as written in `transcript`; 1.0 when none are expected."
  def name_accuracy([], _transcript), do: 1.0
  def name_accuracy(names, transcript), do: names_found(names, transcript) / length(names)

  def names_found(names, transcript), do: Enum.count(names, &String.contains?(transcript, &1))

  defp words(text) do
    text |> String.downcase() |> String.replace(~r/[^\p{L}\p{N}\s]/u, "") |> String.split()
  end

  # Levenshtein over words, one row at a time.
  defp distance(ref, hyp) do
    first = Enum.to_list(0..length(hyp))

    ref
    |> Enum.with_index(1)
    |> Enum.reduce(first, fn {r, i}, prev ->
      hyp
      |> Enum.zip(Enum.zip(prev, tl(prev)))
      |> Enum.reduce([i], fn {h, {diag, up}}, [left | _] = row ->
        [min(min(left, up) + 1, diag + if(r == h, do: 0, else: 1)) | row]
      end)
      |> Enum.reverse()
    end)
    |> List.last()
  end
end
