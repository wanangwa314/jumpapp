defmodule Jumpapp.Intercom.RequestProcessor do
  @moduledoc """
  Processes pending Intercom requests in the background.
  """

  alias Jumpapp.{Repo, TicketMatcher}
  alias Jumpapp.Intercom.Request

  #Jumpapp.Intercom.RequestProcessor.process_pending_requests()

  def process_pending_requests do
    Request.pending_requests()
    |> Repo.all()
    |> Enum.each(&process_request/1)
  end

  defp process_request(request) do
    case TicketMatcher.match_conversation(request.conversation_id, request.conversation_url) do
      {:ok, _result} ->
        request
        |> Request.changeset(%{status: "COMPLETED"})
        |> Repo.update()

      {:error, reason} ->
        request
        |> Request.changeset(%{status: "FAILED"})
        |> Repo.update()

        # Log the error for monitoring
        require Logger
        Logger.error("Failed to process Intercom request: #{inspect(reason)}")
    end
  end
end
