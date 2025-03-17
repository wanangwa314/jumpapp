defmodule Jumpapp.TicketMatcher do
  @moduledoc """
  Service for matching Intercom conversations with existing Notion tickets
  using Google Gemini for semantic matching.
  """

  alias Jumpapp.{
    IntercomService,
    NotionService,
    SlackService,
    ContentGenerator
  }

  def match_conversation(conversation_id, conversation_url) do
    with {:ok, conversation} <- IntercomService.get_conversation(conversation_id),
         {:ok, tickets} <- NotionService.list_tickets(),
         {:ok, match_result} <- ContentGenerator.find_matching_ticket(conversation, tickets) do
      case match_result do
        nil -> create_new_ticket(conversation, conversation_url)
        ticket -> update_existing_ticket(ticket, conversation, conversation_url)
      end
    end
  end

  defp create_new_ticket(conversation, conversation_url) do
    with {:ok, title} <- ContentGenerator.generate_ticket_title(conversation),
         {:ok, summary} <- ContentGenerator.generate_ticket_summary(conversation),
         {:ok, ticket} <- NotionService.create_ticket(title, summary, [conversation_url]),
         {:ok, channel} <- SlackService.create_channel(ticket, title),
         {:ok, _} <- NotionService.update_ticket_slack_channel(ticket["id"], channel["channel"]["id"]),
         {:ok, _} <- SlackService.set_channel_topic(channel["id"], ticket["url"]),
         {:ok, _} <- SlackService.add_conversation_participants(channel["id"], conversation) do
      {:ok, %{
        matched_ticket: ticket,
        conversation_url: conversation_url,
        slack_channel: channel
      }}
    end
  end

  defp update_existing_ticket(ticket, conversation, conversation_url) do
    # Get existing conversation URLs and append the new one
    updated_urls = [conversation_url | ticket["intercom_conversations"]]
    |> Enum.uniq()

    # Use the stored Slack channel ID from the ticket
    channel_id = ticket["slack_channel"]

    with {:ok, channel} <- SlackService.get_channel_by_id(channel_id),
         {:ok, _} <- SlackService.add_conversation_participants(channel_id, conversation),
         {:ok, updated_ticket} <- NotionService.update_ticket_urls(ticket["id"], updated_urls) do
      {:ok, %{
        matched_ticket: updated_ticket,
        conversation_url: conversation_url,
        slack_channel: channel
      }}
    end
  end
end
