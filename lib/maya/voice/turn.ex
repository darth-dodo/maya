defmodule Maya.Voice.Turn do
  @moduledoc "One guest's Question and its Answer, as text, with per-stage milliseconds (ADR-006, ADR-008)."
  use Ecto.Schema
  import Ecto.Query

  alias Maya.Repo

  @stages Maya.Voice.Latency.stages()
  @window 25

  schema "turns" do
    field :guest_id, :string
    field :question, :string
    field :answer, :string
    field :cut, :boolean, default: false
    field :mic_release_ms, :integer
    field :stt_ms, :integer
    field :agent_ms, :integer
    field :tts_first_byte_ms, :integer
    field :playback_start_ms, :integer
    # "realtime" or "batch": which STT gave the final transcript (ADR-009).
    field :stt_source, :string
    # In memory only: the screen shows "voice is down" for this turn.
    field :voice_down, :boolean, virtual: true, default: false

    timestamps(type: :utc_datetime_usec)
  end

  @doc "Turns the agent gets as context, the Conversation keeps and the Talk screen shows."
  def window, do: @window

  @doc "A guest's latest `limit` turns, oldest first."
  def recent(guest_id, limit \\ @window) when is_binary(guest_id) do
    from(t in __MODULE__, where: t.guest_id == ^guest_id, order_by: [desc: t.id], limit: ^limit)
    |> Repo.all()
    |> Enum.reverse()
  end

  def insert(%__MODULE__{} = turn) do
    turn
    |> Ecto.Changeset.change()
    |> Ecto.Changeset.validate_required([:guest_id, :question, :answer])
    |> Repo.insert()
  end

  @doc "Sets stage timings on a stored turn; unknown keys are ignored."
  def put_timings(%__MODULE__{id: id} = turn, timings) when is_integer(id) do
    turn |> Ecto.Changeset.change(Map.take(timings, @stages)) |> Repo.update()
  end

  @doc "Stage timings of every guest's turns: latency is about the voice loop, not a guest."
  def stage_rows, do: Repo.all(from t in __MODULE__, select: map(t, ^@stages))
end
