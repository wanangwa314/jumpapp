defmodule Jumpapp.Intercom.Request do
  use Ecto.Schema
  import Ecto.Changeset
  import Ecto.Query

  schema "intercom_requests" do
    field :conversation_url, :string
    field :conversation_id, :integer
    field :status, :string, default: "PENDING"

    timestamps()
  end

  def changeset(request, attrs) do
    request
    |> cast(attrs, [:conversation_url, :conversation_id, :status])
    |> validate_required([:conversation_url, :conversation_id])
  end

  def pending_requests do
    from r in __MODULE__,
      where: r.status == "PENDING",
      order_by: [asc: r.inserted_at]
  end
end
