defmodule Jumpapp.IntercomService do
  @moduledoc """
  Service for interacting with Intercom API.
  """

  alias Jumpapp.ApiClient

  def get_conversation(id) do
    case ApiClient.get_conversation(id) do
      {:ok, conversation} -> {:ok, conversation}
      {:error, reason} -> {:error, "Failed to fetch conversation: #{inspect(reason)}"}
    end
  end
end
