defmodule Jumpapp.TicketResolver do
  @moduledoc """
  Processes resolved Notion tickets and sends notifications to Slack and Intercom.
  """

  require Logger
  alias Jumpapp.{NotionService, ApiClient, Tickets}

  #Jumpapp.TicketResolver.check_resolved_tickets()
  def check_resolved_tickets do
    # First sync all Notion tickets to our local DB
    sync_notion_tickets()

    # Then check pending_resolve tickets
    Tickets.list_pending_resolve_tickets()
    |> Enum.each(&check_ticket_status/1)
  end

  defp sync_notion_tickets do
    case NotionService.list_tickets() do
      {:ok, tickets} ->
        Enum.each(tickets, &Tickets.sync_notion_ticket/1)
      {:error, reason} ->
        Logger.error("Failed to fetch Notion tickets: #{inspect(reason)}")
    end
  end

  defp check_ticket_status(local_ticket) do
    # Skip if ticket is already resolved locally
    if local_ticket.local_status == "pending_resolve" do
      case NotionService.list_tickets() do
        {:ok, notion_tickets} ->
          notion_ticket = Enum.find(notion_tickets, & &1["id"] == local_ticket.notion_id)

          if notion_ticket && String.upcase(notion_ticket["status"]) == "RESOLVED" do
            notify_resolution(notion_ticket)
            Tickets.mark_as_resolved(local_ticket)
          end

        {:error, reason} ->
          Logger.error("Failed to check Notion ticket status: #{inspect(reason)}")
      end
    end
  end

  defp notify_resolution(ticket) do
    # Notify Slack
    with {:ok, message} <- generate_resolution_message(ticket),
         channel_id when not is_nil(channel_id) <- ticket["slack_channel"] do
      case ApiClient.post_slack_message(channel_id, message) do
        {:ok, _} ->
          Logger.info("Posted resolution message to Slack channel #{channel_id}")
        {:error, reason} ->
          Logger.error("Failed to post Slack message: #{inspect(reason)}")
      end
    end

    # Notify Intercom conversations
    Enum.each(ticket["intercom_conversation_ids"], fn conversation_id ->
      note = """
      🎉 This issue has been resolved in our tracking system!
      Ticket: #{ticket["title"]}
      """
      case ApiClient.add_intercom_note(conversation_id, note) do
        {:ok, _} ->
          Logger.info("Added resolution note to Intercom conversation #{conversation_id}")
        {:error, reason} ->
          Logger.error("Failed to add Intercom note: #{inspect(reason)}")
      end
    end)
  end

  defp generate_resolution_message(ticket) do
    message = """
    🎉 *Issue Resolved*
    The following ticket has been marked as resolved:
    *#{ticket["title"]}*

    Thank you for your patience and collaboration!
    """
    {:ok, message}
  end
end
