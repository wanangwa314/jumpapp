defmodule Jumpapp.Tickets.Ticket do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "tickets" do
    field :notion_id, :string
    field :title, :string
    field :status, :string
    field :slack_channel, :string
    field :intercom_conversation_ids, {:array, :string}
    field :local_status, :string, default: "pending_resolve"

    timestamps(type: :utc_datetime)
  end

  def changeset(ticket, attrs) do
    ticket
    |> cast(attrs, [:notion_id, :title, :status, :slack_channel, :intercom_conversation_ids, :local_status])
    |> validate_required([:notion_id, :title, :status])
    |> unique_constraint(:notion_id)
    |> ensure_string_ids()
  end

  def pending_resolve do
    from(t in __MODULE__, where: t.local_status == "pending_resolve")
  end

  def mark_as_resolved(ticket) do
    ticket
    |> changeset(%{local_status: "resolved"})
  end

  # Private functions

  defp ensure_string_ids(changeset) do
    case get_change(changeset, :intercom_conversation_ids) do
      nil -> changeset
      ids ->
        put_change(changeset, :intercom_conversation_ids, Enum.map(ids, &to_string/1))
    end
  end
end
