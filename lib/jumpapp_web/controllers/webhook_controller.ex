defmodule JumpappWeb.WebhookController do
  use JumpappWeb, :controller
  alias Jumpapp.Intercom.Request
  alias Jumpapp.Repo

  def intercom(conn, %{"conversation_url" => url, "conversation_id" => id}) do
    case create_request(url, id) do
      {:ok, _request} ->
        json(conn, %{status: "ok", message: "Request queued for processing"})
      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{error: format_errors(changeset)})
    end
  end

  defp create_request(url, id) do
    %Request{}
    |> Request.changeset(%{
      conversation_url: url,
      conversation_id: id,
      status: "PENDING"
    })
    |> Repo.insert()
  end

  defp format_errors(changeset) do
    Ecto.Changeset.traverse_errors(changeset, fn {msg, opts} ->
      Enum.reduce(opts, msg, fn {key, value}, acc ->
        String.replace(acc, "%{#{key}}", to_string(value))
      end)
    end)
  end
end
