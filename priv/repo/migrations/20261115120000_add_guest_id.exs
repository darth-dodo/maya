defmodule Maya.Repo.Migrations.AddGuestId do
  use Ecto.Migration

  # ADR-008: turns and Progress belong to a guest. Rows from before guests go to "legacy";
  # the default is dropped afterwards so code must always set the guest.
  def change do
    for table <- [:turns, :progress] do
      alter table(table) do
        add :guest_id, :string, null: false, default: "legacy"
      end

      alter table(table) do
        modify :guest_id, :string,
          null: false,
          default: nil,
          from: {:string, null: false, default: "legacy"}
      end
    end

    create index(:turns, [:guest_id])
    create unique_index(:progress, [:guest_id])

    # The old seed wrote id 1 by hand, so the sequence never moved: move it past the rows.
    execute """
            SELECT setval(pg_get_serial_sequence('progress', 'id'),
                          GREATEST((SELECT MAX(id) FROM progress), 1))
            """,
            "SELECT 1"
  end
end
