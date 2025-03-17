defmodule Jumpapp.Repo.Migrations.CreateTickets do
  use Ecto.Migration

  def change do
    create table(:tickets) do
      add :notion_id, :string, null: false
      add :title, :string, null: false
      add :status, :string, null: false
      add :slack_channel, :string
      add :intercom_conversation_ids, {:array, :string}
      add :local_status, :string, default: "pending_resolve"

      timestamps(type: :utc_datetime)
    end

    create unique_index(:tickets, [:notion_id])
  end
end
