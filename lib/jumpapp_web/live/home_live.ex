defmodule JumpappWeb.HomeLive do
  use JumpappWeb, :live_view
  alias Jumpapp.Tickets

  @impl true
  def mount(_params, _session, socket) do
    if connected?(socket) do
      :timer.send_interval(5000, self(), :update_data)
    end

    {:ok, assign_data(socket)}
  end

  @impl true
  def handle_info(:update_data, socket) do
    {:noreply, assign_data(socket)}
  end

  defp assign_data(socket) do
    tickets = Tickets.list_all_tickets()
    stats = %{
      total_tickets: length(tickets),
      pending_resolve: Enum.count(tickets, & &1.local_status == "pending_resolve"),
      resolved: Enum.count(tickets, & &1.local_status == "resolved")
    }

    socket
    |> assign(:tickets, tickets)
    |> assign(:stats, stats)
  end
end
