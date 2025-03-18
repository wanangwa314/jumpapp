defmodule Jumpapp.SlackService do
  @moduledoc """
  Service for interacting with Slack API.
  """

  require Logger
  alias Jumpapp.ApiClient

  def create_channel(_ticket, title) do
    channel_name = sanitize_channel_name(title)

    case ApiClient.create_channel(channel_name) do
      {:ok, channel} -> {:ok, channel}
      {:error, reason} -> {:error, "Failed to create Slack channel: #{inspect(reason)}"}
    end
  end

  def set_channel_topic(channel_id, topic) do
    case ApiClient.set_channel_topic(channel_id, topic) do
      {:ok, response} -> {:ok, response}
      {:error, reason} -> {:error, "Failed to set channel topic: #{inspect(reason)}"}
    end
  end

  def add_conversation_participants(channel_id, conversation) do
    with {:ok, users} <- match_users_with_jaro(conversation) do
      case users do
        [] ->
          Logger.info("No matching Slack users found for conversation participants")
          {:ok, []}
        users ->
          Enum.reduce_while(users, {:ok, []}, fn user_id, {:ok, acc} ->
            case ApiClient.invite_user(channel_id, user_id) do
              {:ok, response} -> {:cont, {:ok, [response | acc]}}
              {:error, reason} -> {:halt, {:error, "Failed to invite user: #{inspect(reason)}"}}
            end
          end)
      end
    end
  end

  def match_users_with_jaro(conversation) do
    {:ok, %{"members" => members}} = ApiClient.list_users()
    active_slack_users = Enum.filter(members, fn user ->
      not user["deleted"] and not user["is_bot"]
    end)

    participants = extract_participants(conversation)

    # Match Intercom participants with Slack users
    matched_users = Enum.flat_map(participants, fn participant ->
      participant_email = get_in(participant, ["email"])
      participant_name = get_in(participant, ["name"])

      if participant_email do
        # Try exact email match first
        case Enum.find(active_slack_users, fn user ->
          user["name"] == String.split(participant_email, "@") |> hd()
        end) do
          nil ->
            # If no email match, try name matching
            case participant_name && Enum.find(active_slack_users, fn user ->
              String.jaro_distance(
                String.downcase(user["real_name"] || ""),
                String.downcase(participant_name)
              ) > 0.8
            end) do
              nil -> []
              slack_user -> [slack_user["id"]]
            end
          slack_user -> [slack_user["id"]]
        end
      else
        []
      end
    end)
    {:ok, Enum.uniq(matched_users)}
  end

  defp extract_participants(conversation) do
    contacts = get_in(conversation, ["contacts", "contacts"]) || []
    admins = get_in(conversation, ["conversation_parts", "conversation_parts"])
    |> List.wrap()
    |> Enum.map(& &1["author"])
    |> Enum.reject(&is_nil/1)

    (contacts ++ admins) |> Enum.uniq_by(& &1["id"])
  end

  defp sanitize_channel_name(title) do
    title
    |> String.downcase()
    |> String.replace(~r/[^a-z0-9\-_]+/, "-")
    |> String.replace(~r/-+/, "-")
    |> String.trim("-")
    |> String.slice(0, 80)
  end
end
