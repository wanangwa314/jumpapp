defmodule Jumpapp.ApiClient do
  @moduledoc """
  API client for making HTTP requests to external services:
  - Intercom
  - Notion
  - Slack
  - Google Gemini
  """

  # Intercom endpoints
  def get_conversation(conversation_id) do
    request(:get, "#{intercom_url()}/conversations/#{conversation_id}", intercom_headers())
  end

  def get_admin_users do
    request(:get, "#{intercom_url()}/admins", intercom_headers())
  end

  # Notion endpoints
  def list_notion_tickets do
    request(:post, "#{notion_url()}/databases/#{notion_database_id()}/query", %{}, notion_headers())
  end

  def create_notion_ticket(params) do
    request(:post, "#{notion_url()}/pages", params, notion_headers())
  end

  def update_notion_ticket(page_id, params) do
    request(:patch, "#{notion_url()}/pages/#{page_id}", params, notion_headers())
  end

  # Slack endpoints
  def list_slack_users do
    request(:get, "#{slack_url()}/users.list", slack_headers())
  end

  def list_channels do
    request(:get, "#{slack_url()}/conversations.list", slack_headers())
  end

  def get_channel_by_id(channel_id) do
    request(:get, "#{slack_url()}/conversations.info", %{channel: channel_id}, slack_headers())
  end

  def create_channel(name) do
    request(:post, "#{slack_url()}/conversations.create", %{name: name}, slack_headers())
  end

  def set_channel_topic(channel_id, topic) do
    request(:post, "#{slack_url()}/conversations.setTopic", %{channel: channel_id, topic: topic}, slack_headers())
  end

  def invite_users(channel_id, user_ids) when is_list(user_ids) do
    request(:post, "#{slack_url()}/conversations.invite", %{channel: channel_id, users: Enum.join(user_ids, ",")}, slack_headers())
  end

  # Google Gemini endpoints
  def generate_content(prompt) do
    request(:post, gemini_url(), %{contents: [%{parts: [%{text: prompt}]}]}, gemini_headers())
  end

  # Private functions

  defp request(method, url, headers) when is_list(headers) do
    request(method, url, "", headers)
  end

  defp request(method, url, body, headers) do
    case HTTPoison.request(method, url, Jason.encode!(body), headers, options: [recv_timeout: 60_000]) do
      {:ok, %{status_code: status, body: response_body}} when status in 200..299 ->
        {:ok, Jason.decode!(response_body)}
      {:ok, %{status_code: status, body: response_body}} ->
        {:error, %{status: status, body: Jason.decode!(response_body)}}
      {:error, %{reason: reason}} ->
        {:error, reason}
    end
  end

  # Base URLs
  defp intercom_url, do: "https://api.intercom.io"
  defp notion_url, do: "https://api.notion.com/v1"
  defp slack_url, do: "https://slack.com/api"
  defp gemini_url, do: "https://generativelanguage.googleapis.com/v1beta/models/gemini-2.0-flash-lite:generateContent"

  # Headers
  defp intercom_headers do
    [
      {"Authorization", "Bearer #{intercom_api_key()}"},
      {"Accept", "application/json"},
      {"Content-Type", "application/json"}
    ]
  end

  defp notion_headers do
    [
      {"Authorization", "Bearer #{notion_api_key()}"},
      {"Notion-Version", "2022-06-28"},
      {"Content-Type", "application/json"}
    ]
  end

  defp slack_headers do
    [
      {"Authorization", "Bearer #{slack_api_token()}"},
      {"Content-Type", "application/json"}
    ]
  end

  defp gemini_headers do
    [
      {"x-goog-api-key", google_gemini_api_key()},
      {"Content-Type", "application/json"}
    ]
  end

  # Environment variables
  defp intercom_api_key, do: System.get_env("INTERCOM_API_KEY")
  defp notion_api_key, do: System.get_env("NOTION_API_KEY")
  defp notion_database_id, do: System.get_env("NOTION_DATABASE_ID")
  defp slack_api_token, do: System.get_env("SLACK_API_TOKEN")
  defp google_gemini_api_key, do: System.get_env("GOOGLE_GEMINI_API_KEY")
end
