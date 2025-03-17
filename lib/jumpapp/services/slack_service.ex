defmodule Jumpapp.SlackService do
  @moduledoc """
  Service for interacting with Slack API and managing channels.
  """

  alias Jumpapp.ApiClient

  def create_channel(ticket, title) do
    prefix = get_in(ticket, ["properties", "ID", "unique_id", "prefix"])
    number = get_in(ticket, ["properties", "ID", "unique_id", "number"])

    id = "#{prefix}-#{number}"
    # Slack channel names must be lowercase, no periods, and limited special chars
    channel_name = id
                  |> Kernel.<>("-" <> title)
                  |> String.downcase()
                  |> String.replace(~r/[^a-z0-9\-_]/, "")
                  |> String.slice(0, 80) # Slack has an 80-char limit on channel names

    case ApiClient.create_channel(channel_name) |> dbg() do
      {:ok, channel} -> {:ok, channel}
      {:error, reason} -> {:error, "Failed to create Slack channel: #{inspect(reason)}"}
    end
  end

  def get_channel_by_id(channel_id) do
    case ApiClient.get_channel_by_id(channel_id) do
      {:ok, channel} -> {:ok, channel}
      {:error, reason} -> {:error, "Failed to get Slack channel: #{inspect(reason)}"}
    end
  end

  def set_channel_topic(channel_id, topic_url) do
    case ApiClient.set_channel_topic(channel_id, topic_url) do
      {:ok, result} -> {:ok, result}
      {:error, reason} -> {:error, "Failed to set channel topic: #{inspect(reason)}"}
    end
  end

  def add_conversation_participants(channel_id, conversation) do
    with {:ok, slack_users} <- ApiClient.list_slack_users(),
         {:ok, matched_users} <- match_users_with_jaro(conversation, slack_users) do
      case matched_users do
        [] -> {:ok, "No matching users found"}
        user_ids -> ApiClient.invite_users(channel_id, user_ids)
      end
    end
  end

  defp match_users_with_jaro(conversation, %{"members" => slack_users}) do
    # Filter out bots and inactive users from Slack
    active_slack_users = Enum.filter(slack_users, fn user ->
      not user["is_bot"] and not user["deleted"] and user["profile"]["email"] != nil
    end)

    # Get all participants from the conversation
    participants = extract_participants(conversation)

    # Match Intercom participants with Slack users
    matched_users = Enum.flat_map(participants, fn participant ->
      participant_email = get_in(participant, ["email"])
      participant_name = get_in(participant, ["name"]) || ""

      # First try exact email match
      case find_by_email(active_slack_users, participant_email) do
        nil ->
          # If no email match, try name matching with Jaro distance
          find_by_name(active_slack_users, participant_name)
        slack_user ->
          [slack_user["id"]]
      end
    end)

    {:ok, Enum.uniq(matched_users)}
  end

  defp extract_participants(conversation) do
    [
      # Include the contact/user who started the conversation
      get_in(conversation, ["source", "author"]),
      # Include the assigned admin if present
      get_in(conversation, ["assignee"]),
      # Include all admins who participated in conversation parts
      get_in(conversation, ["conversation_parts", "conversation_parts"])
      |> List.wrap()
      |> Enum.flat_map(fn part ->
        case get_in(part, ["author", "type"]) do
          "admin" -> [get_in(part, ["author"])]
          _ -> []
        end
      end)
    ]
    |> List.flatten()
    |> Enum.reject(&is_nil/1)
    |> Enum.uniq_by(& &1["id"])
  end

  defp find_by_email(_slack_users, nil), do: nil
  defp find_by_email(slack_users, email) do
    Enum.find(slack_users, fn user ->
      String.downcase(user["profile"]["email"]) == String.downcase(email)
    end)
  end

  defp find_by_name(slack_users, name) do
    # Find best matching user using Jaro-Winkler distance
    best_match = Enum.reduce(slack_users, {nil, 0.0}, fn user, {best_user, best_score} ->
      user_name = get_in(user, ["profile", "real_name"]) || ""
      user_display_name = get_in(user, ["profile", "display_name"]) || ""

      # Try both real name and display name
      real_name_score = String.jaro_distance(String.downcase(name), String.downcase(user_name))
      display_name_score = String.jaro_distance(String.downcase(name), String.downcase(user_display_name))

      # Use the higher score between real name and display name
      score = max(real_name_score, display_name_score)

      if score > best_score and score > 0.8 do
        {user, score}
      else
        {best_user, best_score}
      end
    end)

    case best_match do
      {nil, _} -> []
      {user, _} -> [user["id"]]
    end
  end
end
