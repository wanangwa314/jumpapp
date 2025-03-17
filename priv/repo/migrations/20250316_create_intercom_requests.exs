defmodule Jumpapp.Repo.Migrations.CreateIntercomRequests do
  use Ecto.Migration

  def change do
    create table(:intercom_requests) do
      add :conversation_url, :string, null: false
      add :conversation_id, :integer, null: false
      add :status, :string, default: "PENDING"

      timestamps()
    end

    create index(:intercom_requests, [:status])
  end
end
