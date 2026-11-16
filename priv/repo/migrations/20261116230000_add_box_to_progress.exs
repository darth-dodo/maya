defmodule Maya.Repo.Migrations.AddBoxToProgress do
  use Ecto.Migration

  # #116: a catch with a full Team goes to the PC box. Additive with a default, so existing
  # rows keep their data and get an empty box.
  def change do
    alter table(:progress) do
      add :box, :jsonb, null: false, default: "[]"
    end
  end
end
