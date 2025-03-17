defmodule Jumpapp.NotionService do
  @moduledoc """
  Service for interacting with Notion API and managing tickets.
  """

  alias Jumpapp.ApiClient

  def list_tickets do
    case ApiClient.list_notion_tickets() do
      {:ok, %{"results" => results}} ->
        tickets = Enum.map(results, fn page ->
          %{
            "id" => page["id"],
            "title" => get_title(page),
            "slack_channel" => get_slack_channel(page),
            "intercom_conversations" => get_intercom_conversations(page),
            "status" => get_status(page),
            "properties" => page["properties"]  # Include full properties for debugging
          }
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

  defp get_status(page) do
    case get_in(page, ["properties", "Status", "status"]) do
      %{"name" => name} -> name
      _ -> nil
    end
  end

  def create_ticket(title, text_body, conversation_urls) do
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
        "text_body" => %{
          "rich_text" => [%{"text" => %{"content" => text_body}}]
        },
        "slack_channel" => %{
          "rich_text" => []  # Will be updated after channel creation
        }
      }
    }

    case ApiClient.create_notion_ticket(params) do
      {:ok, ticket} -> {:ok, ticket}
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

    case ApiClient.update_notion_ticket(ticket_id, params) do
      {:ok, ticket} -> {:ok, ticket}
      {:error, reason} -> {:error, "Failed to update Notion ticket slack channel: #{inspect(reason)}"}
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

    case ApiClient.update_notion_ticket(ticket_id, params) do
      {:ok, ticket} -> {:ok, ticket}
      {:error, reason} -> {:error, "Failed to update Notion ticket URLs: #{inspect(reason)}"}
    end
  end
end
