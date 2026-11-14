defmodule Maya.Voice.Turn do
  @moduledoc "One Question and its Answer, as text, with per-stage milliseconds (ADR-006)."
  use Ecto.Schema
  import Ecto.Query

  alias Maya.Repo

  @stages Maya.Voice.Latency.stages()

  schema "turns" do
    field :question, :string
    field :answer, :string
    field :cut, :boolean, default: false
    field :mic_release_ms, :integer
    field :stt_ms, :integer
    field :agent_ms, :integer
    field :tts_first_byte_ms, :integer
    field :playback_start_ms, :integer
    # In memory only: the screen shows "voice is down" for this turn.
    field :voice_down, :boolean, virtual: true, default: false

    timestamps(type: :utc_datetime_usec)
  end

  @doc "The latest `limit` turns, oldest first."
  def recent(limit \\ 20) do
    from(t in __MODULE__, order_by: [desc: t.id], limit: ^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  def insert(%__MODULE__{} = turn) do
    turn
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.validate_required([:question, :answer])
    |> Repo.insert()
  end

  @doc "Sets stage timings on a stored turn; unknown keys are ignored."
  def put_timings(%__MODULE__{id: id} = turn, timings) when is_integer(id) do
    turn |> Ecto.Changeset.change(Map.take(timings, @stages)) |> Repo.update()
  end

  def stage_rows, do: Repo.all(from t in __MODULE__, select: map(t, ^@stages))
end
