defmodule Jumpapp.NotionService do
  @moduledoc """
  Service for interacting with Notion API and managing tickets.
  """

  alias Jumpapp.{ApiClient, Tickets}

  def list_tickets do
    case ApiClient.list_notion_tickets() do
      {:ok, %{"results" => results}} ->
        tickets = Enum.map(results, fn page ->
          %{
            "id" => page["id"],
            "title" => get_title(page),
            "slack_channel" => get_slack_channel(page),
            "intercom_conversations" => get_intercom_conversations(page),
            "intercom_conversation_ids" => get_intercom_conversation_ids(page),
            "status" => get_status(page),
            "properties" => page["properties"]  # Include full properties for debugging
          }
        end)
        Enum.each(tickets, fn ticket ->
          sync_ticket_to_local_db(ticket)
        end)
        {:ok, tickets}
      {:error, reason} ->
        {:error, "Failed to fetch Notion tickets: #{inspect(reason)}"}
    end
  end

  defp get_title(page) do
    case get_in(page, ["properties", "Name", "title"]) do
      [%{"text" => %{"content" => content}} | _] -> content
      _ -> nil
    end
  end

  defp get_slack_channel(page) do
    case get_in(page, ["properties", "slack_channel", "rich_text"]) do
      [%{"text" => %{"content" => content}} | _] -> content
      _ -> nil
    end
  end

  defp get_intercom_conversations(page) do
    case get_in(page, ["properties", "intercom_conversations", "rich_text"]) do
      conversations when is_list(conversations) ->
        Enum.map(conversations, fn
          %{"text" => %{"content" => content}} -> content
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)
      _ -> []
    end
  end

  defp get_intercom_conversation_ids(page) do
    case get_in(page, ["properties", "intercom_conversation_ids", "rich_text"]) do
      conversations when is_list(conversations) ->
        Enum.map(conversations, fn
          %{"text" => %{"content" => content}} -> content
          _ -> nil
        end)
        |> Enum.reject(&is_nil/1)
      _ -> []
    end
  end

  defp get_status(page) do
    case get_in(page, ["properties", "Status", "status"]) do
      %{"name" => name} -> name
      _ -> nil
    end
  end

  def create_ticket(title, text_body, conversation_urls, conversation_ids) do
    params = %{
      "parent" => %{"database_id" => System.get_env("NOTION_DATABASE_ID")},
      "properties" => %{
        "Name" => %{
          "title" => [%{"text" => %{"content" => title}}]
        },
        "intercom_conversations" => %{
          "rich_text" => Enum.map(conversation_urls, fn url ->
            %{"text" => %{"content" => url}}
          end)
        },
        "intercom_conversation_ids" => %{
          "rich_text" => Enum.map(conversation_ids, fn id ->
            %{"text" => %{"content" => id}}
          end)
        },
        "text_body" => %{
          "rich_text" => [%{"text" => %{"content" => text_body}}]
        },
        "slack_channel" => %{
          "rich_text" => []  # Will be updated after channel creation
        }
      }
    }

    with {:ok, ticket} <- ApiClient.create_notion_ticket(params) do
      # Create in local DB
      ticket_attrs = %{
        notion_id: ticket["id"],
        title: title,
        status: "Not Started",
        slack_channel: "",
        intercom_conversation_ids: conversation_ids,
        local_status: "pending_resolve"
      }
      case Tickets.create_ticket(ticket_attrs) do
        {:ok, _local_ticket} -> {:ok, ticket}
        {:error, reason} -> {:error, "Failed to create local ticket: #{inspect(reason)}"}
      end
    else
      {:error, reason} -> {:error, "Failed to create Notion ticket: #{inspect(reason)}"}
    end
  end

  def update_ticket_slack_channel(ticket_id, channel_id) do
    params = %{
      "properties" => %{
        "slack_channel" => %{
          "rich_text" => [%{"text" => %{"content" => channel_id}}]
        }
      }
    }

    with {:ok, ticket} <- ApiClient.update_notion_ticket(ticket_id, params),
         {:ok, local_ticket} <- Tickets.get_ticket(ticket_id) do
      # Update local DB
      Tickets.update_ticket(local_ticket, %{slack_channel: channel_id})
      {:ok, ticket}
    else
      {:error, reason} -> {:error, "Failed to update ticket slack channel: #{inspect(reason)}"}
    end
  end

  def update_ticket_urls(ticket_id, urls) do
    params = %{
      "properties" => %{
        "intercom_conversations" => %{
          "rich_text" => Enum.map(urls, fn url ->
            %{"text" => %{"content" => url}}
          end)
        }
      }
    }

    with {:ok, ticket} <- ApiClient.update_notion_ticket(ticket_id, params) do
      # Update local DB
      sync_ticket_to_local_db(ticket)
      {:ok, ticket}
    else
      {:error, reason} -> {:error, "Failed to update Notion ticket URLs: #{inspect(reason)}"}
    end
  end

  def update_ticket_ids(ticket_id, ids) do
    params = %{
      "properties" => %{
        "intercom_conversation_ids" => %{
          "rich_text" => Enum.map(ids, fn id ->
            %{"text" => %{"content" => id}}
          end)
        }
      }
    }

    with {:ok, ticket} <- ApiClient.update_notion_ticket(ticket_id, params),
         {:ok, local_ticket} <- Tickets.get_ticket(ticket_id) do
      # Update local DB
      Tickets.update_ticket(local_ticket, %{intercom_conversation_ids: ids})
      {:ok, ticket}
    else
      {:error, reason} -> {:error, "Failed to update ticket IDs: #{inspect(reason)}"}
    end
  end

  def sync_ticket_to_local_db(notion_ticket) do
    case Tickets.get_ticket(notion_ticket["id"]) do
      {:ok, local_ticket} ->
        # Update existing ticket but preserve local_status
        ticket_attrs = %{
          notion_id: notion_ticket["id"],
          title: notion_ticket["title"],
          status: notion_ticket["status"],
          slack_channel: notion_ticket["slack_channel"],
          intercom_conversation_ids: notion_ticket["intercom_conversation_ids"]
        }
        Tickets.update_ticket(local_ticket, ticket_attrs)

      {:error, :not_found} ->
        # Create new ticket with pending_resolve status
        ticket_attrs = %{
          notion_id: notion_ticket["id"],
          title: notion_ticket["title"],
          status: notion_ticket["status"],
          slack_channel: notion_ticket["slack_channel"],
          intercom_conversation_ids: notion_ticket["intercom_conversation_ids"],
          local_status: "pending_resolve"
        }
        Tickets.create_ticket(ticket_attrs)
    end
  end
end
