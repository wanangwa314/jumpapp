defmodule Jumpapp.Tickets do
  @moduledoc """
  The Tickets context.
  """

  import Ecto.Query, warn: false
  alias Jumpapp.Repo
  alias Jumpapp.Tickets.Ticket

  def get_ticket!(notion_id), do: Repo.get_by!(Ticket, notion_id: notion_id)

  def get_ticket(notion_id) do
    case Repo.get_by(Ticket, notion_id: notion_id) do
      nil -> {:error, :not_found}
      ticket -> {:ok, ticket}
    end
  end

  # Jumpapp.Tickets.list_pending_resolve_tickets()
  def list_pending_resolve_tickets do
    Ticket
    |> where([t], t.local_status == "pending_resolve")
    |> Repo.all()
  end

  # Jumpapp.Tickets.list_all_tickets()
  def list_all_tickets do
    Ticket
    |> order_by([t], [desc: t.updated_at])
    |> Repo.all()
  end

  def create_ticket(attrs \\ %{}) do
    %Ticket{}
    |> Ticket.changeset(attrs)
    |> Repo.insert(
      on_conflict: [set: [
        status: attrs[:status] || attrs["status"],
        title: attrs[:title] || attrs["title"],
        slack_channel: attrs[:slack_channel] || attrs["slack_channel"],
        intercom_conversation_ids: attrs[:intercom_conversation_ids] || attrs["intercom_conversation_ids"],
        updated_at: DateTime.utc_now()
      ]],
      conflict_target: [:notion_id]
    )
  end

  def update_ticket(%Ticket{} = ticket, attrs) do
    ticket
    |> Ticket.changeset(attrs)
    |> Repo.update()
  end

  def mark_as_resolved(%Ticket{} = ticket) do
    ticket
    |> Ticket.mark_as_resolved()
    |> Repo.update()
  end

  def sync_notion_ticket(notion_ticket) do
    attrs = %{
      notion_id: notion_ticket["id"],
      title: notion_ticket["title"],
      status: notion_ticket["status"],
      slack_channel: notion_ticket["slack_channel"],
      intercom_conversation_ids: notion_ticket["intercom_conversation_ids"]
    }

    create_ticket(attrs)
  end
end
