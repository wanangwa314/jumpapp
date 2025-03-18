defmodule Jumpapp.TicketMatcher do
  @moduledoc """
  Matches Intercom conversations with Notion tickets and creates Slack channels.
  """

  require Logger
  alias Jumpapp.{NotionService, SlackService, ContentGenerator}

  def match_conversation(conversation_id, conversation_url) do
    with {:ok, conversation} <- get_conversation(conversation_id),
         {:ok, tickets} <- NotionService.list_tickets() do

      case find_existing_ticket(tickets, conversation_url) do
        nil ->
          create_new_ticket(conversation, conversation_url, to_string(conversation_id))
        ticket ->
          update_existing_ticket(ticket, conversation, conversation_url, to_string(conversation_id))
      end
    end
  end

  defp create_new_ticket(conversation, conversation_url, conversation_id) do
    with {:ok, title} <- ContentGenerator.generate_ticket_title(conversation),
         {:ok, summary} <- ContentGenerator.generate_ticket_summary(conversation),
         {:ok, ticket} <- NotionService.create_ticket(title, summary, [conversation_url], [conversation_id]),
         {:ok, channel} <- SlackService.create_channel(ticket, title),
         {:ok, _} <- NotionService.update_ticket_slack_channel(ticket["id"], channel["channel"]["id"]),
         {:ok, _} <- SlackService.set_channel_topic(channel["id"], ticket["url"]),
         {:ok, _} <- SlackService.add_conversation_participants(channel["id"], conversation) do
      {:ok, %{
        ticket_id: ticket["id"],
        channel_id: channel["id"]
      }}
    end
  end

  defp update_existing_ticket(ticket, conversation, conversation_url, conversation_id) do
    updated_urls = [conversation_url | ticket["intercom_conversations"]]
    |> Enum.uniq()

    updated_ids = [conversation_id | ticket["intercom_conversation_ids"]]
    |> Enum.uniq()

    channel_id = ticket["slack_channel"]

    with {:ok, _} <- NotionService.update_ticket_urls(ticket["id"], updated_urls),
         {:ok, _} <- NotionService.update_ticket_ids(ticket["id"], updated_ids),
         {:ok, _} <- SlackService.add_conversation_participants(channel_id, conversation) do
      {:ok, %{
        ticket_id: ticket["id"],
        channel_id: channel_id
      }}
    end
  end

  defp find_existing_ticket(tickets, conversation_url) do
    Enum.find(tickets, fn ticket ->
      conversation_url in ticket["intercom_conversations"]
    end)
  end

  defp get_conversation(conversation_id) do
    case Jumpapp.ApiClient.get_conversation(conversation_id) do
      {:ok, conversation} -> {:ok, conversation}
      {:error, reason} -> {:error, "Failed to get conversation: #{inspect(reason)}"}
    end
  end
end
