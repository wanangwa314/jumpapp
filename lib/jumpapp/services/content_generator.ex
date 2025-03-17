defmodule Jumpapp.ContentGenerator do
  @moduledoc """
  Service for generating content using AI models.
  """

  alias Jumpapp.ApiClient

  def generate_ticket_title(conversation) do
    prompt = """
    Task: Generate a concise, descriptive title for this support ticket based on the Intercom conversation.
    The title should be clear, professional, and summarize the main issue.
    Maximum length: 60 characters.

    Conversation:
    #{Jason.encode!(conversation)}

    Return ONLY the title, nothing else.
    """

    case ApiClient.generate_content(prompt) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => title} | _]}} | _]}} ->
        {:ok, String.trim(title)}
      {:error, reason} ->
        {:error, "Failed to generate title: #{inspect(reason)}"}
    end
  end

  def generate_ticket_summary(conversation) do
    Process.sleep(5000) # Allow for rate limit on gemini endpoint
    prompt = """
    Task: Create a short and concise summary of this Intercom conversation and what needs to be fixed.
    Include:
    1. Key points from the conversation
    2. Main issues identified
    3. Clear summary of what needs to be fixed or addressed

    Conversation:
    #{Jason.encode!(conversation)}

    Provide a well-structured, professional summary.
    """
    case ApiClient.generate_content(prompt) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => summary} | _]}} | _]}} ->
        {:ok, String.trim(summary)}
      {:error, reason} ->
        {:error, "Failed to generate summary: #{inspect(reason)}"}
    end
  end

  def find_matching_ticket(conversation, tickets) do
    titles = Enum.map_join(tickets, "\n", & &1["title"])

    prompt = """
    Task: Compare the following Intercom conversation with a list of ticket titles and determine if the conversation belongs to any of these tickets.
    If there's no clear match, return "NOT FOUND".

    Conversation:
    #{Jason.encode!(conversation)}

    Ticket Titles:
    #{titles}

    Return ONLY the exact matching title or "NOT FOUND" if no match is found.
    """

    case ApiClient.generate_content(prompt) do
      {:ok, %{"candidates" => [%{"content" => %{"parts" => [%{"text" => result} | _]}} | _]}} ->
        matched_ticket = case result do
          "NOT FOUND" -> nil
          title -> Enum.find(tickets, &(&1["title"] == String.trim(title)))
        end
        {:ok, matched_ticket}
      {:error, reason} ->
        {:error, "Failed to match conversation: #{inspect(reason)}"}
    end
  end
end
