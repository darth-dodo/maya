defmodule Mix.Tasks.Maya.CompareModels do
  @shortdoc "Runs the Roxanne Question through 2 or 3 agent models and prints agent ms"
  @moduledoc """
  Runs "How do I earn Roxanne's badge?" through each model (the ADR-007 candidates by
  default) against the real OpenRouter and Progress, and prints the agent-stage milliseconds
  and the Answer. Needs `OPENROUTER_API_KEY` and an imported database.

      mix maya.compare_models
      mix maya.compare_models anthropic/claude-haiku-5.5 openai/gpt-5.4-mini
  """
  use Mix.Task

  @requirements ["app.start"]
  @question "How do I earn Roxanne's badge?"
  # ADR-007 candidates: tool-capable on https://openrouter.ai/api/v1/models?supported_parameters=tools
  @candidates ["anthropic/claude-haiku-5.5", "google/gemini-3.8-flash", "openai/gpt-5.4-mini"]

  @impl true
  def run(args) do
    for model <- if(args == [], do: @candidates, else: args) do
      {us, result} = :timer.tc(fn -> Maya.Agent.answer(@question, [], model: model) end)

      answer =
        case result do
          {:ok, text} -> text
          {:error, reason} -> "error: #{inspect(reason)}"
        end

      Mix.shell().info("#{model}  #{div(us, 1000)} ms  #{answer}")
    end

    :ok
  end
end
