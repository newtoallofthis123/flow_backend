defmodule FlowApiWeb.UserChannel do
  use FlowApiWeb, :channel

  alias FlowApiWeb.Channels.Presence

  @doc """
  Join the user's personal channel.
  Topic format: "user:{user_id}"
  Only allows users to join their own channel.
  """
  def join("user:" <> user_id, _payload, socket) do
    if socket.assigns.user_id == user_id do
      send(self(), :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def join(_topic, _payload, _socket) do
    {:error, %{reason: "invalid_topic"}}
  end

  @doc """
  Handle messages from the client.
  """
  def handle_in("ping", _payload, socket) do
    {:reply, {:ok, %{event: "pong", data: %{timestamp: DateTime.utc_now() |> DateTime.to_iso8601()}}}, socket}
  end

  def handle_in(_event, _payload, socket) do
    {:noreply, socket}
  end

  @doc """
  Handle info messages (like :after_join).
  """
  def handle_info(:after_join, socket) do
    user_id = socket.assigns.user_id

    # Track user presence
    Presence.track(
      socket,
      user_id,
      %{
        online_at: DateTime.utc_now() |> DateTime.to_iso8601(),
        user_id: user_id
      }
    )

    # Push current presence state to the client
    push(socket, "presence_state", Presence.list(socket))

    {:noreply, socket}
  end

  # Handle broadcasts from Phoenix.Channel.broadcast
  def handle_info(%Phoenix.Socket.Broadcast{event: event, payload: payload}, socket) do
    push(socket, event, payload)
    {:noreply, socket}
  end

  # Handle presence diffs
  def handle_info(%Phoenix.Socket.Broadcast{event: "presence_diff", payload: diff}, socket) do
    push(socket, "presence_diff", diff)
    {:noreply, socket}
  end

  def handle_info(_msg, socket) do
    {:noreply, socket}
  end
end
