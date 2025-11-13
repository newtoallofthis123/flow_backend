defmodule FlowApiWeb.UserSocket do
  use Phoenix.Socket

  require Logger

  alias FlowApi.Sessions.Session

  ## Channels
  channel "user:*", FlowApiWeb.UserChannel

  @doc """
  Connect to the socket with JWT token authentication.
  Token is passed as a query parameter: ?token={jwt_token}

  On successful authentication, starts a Session GenServer for the user.
  """
  def connect(%{"token" => token}, socket, _connect_info) do
    case FlowApi.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case FlowApi.Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            socket = assign(socket, :user_id, user.id)

            # Start session GenServer
            case start_session(user.id) do
              {:ok, session_pid} ->
                Logger.info("Session started for user #{user.id}: #{inspect(session_pid)}")
                socket = assign(socket, :session_pid, session_pid)
                {:ok, socket}

              {:error, {:already_started, session_pid}} ->
                # Session already exists, this is fine (reconnection scenario)
                Logger.info("Session already exists for user #{user.id}: #{inspect(session_pid)}")
                socket = assign(socket, :session_pid, session_pid)
                {:ok, socket}

              {:error, reason} ->
                Logger.error("Failed to start session for user #{user.id}: #{inspect(reason)}")
                :error
            end

          {:error, _reason} ->
            :error
        end

      {:error, _reason} ->
        :error
    end
  end

  def connect(_params, _socket, _connect_info) do
    :error
  end

  @doc """
  Socket id is used to identify all sockets for a given user.
  """
  def id(socket), do: "user_socket:#{socket.assigns.user_id}"

  @doc """
  Called when the socket disconnects.
  Optionally stops the session immediately, or let it timeout naturally.
  """
  def terminate(_reason, socket) do
    user_id = socket.assigns[:user_id]

    if user_id do
      Logger.info("Socket disconnected for user #{user_id}")
      # Optionally stop the session immediately
      # Session.stop_session(user_id)
      # Or let it timeout naturally
    end

    :ok
  end

  # Private Helpers

  defp start_session(user_id) do
    DynamicSupervisor.start_child(
      FlowApi.SessionSupervisor,
      {Session, [user_id: user_id]}
    )
  end
end
