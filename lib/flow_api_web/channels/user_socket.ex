defmodule FlowApiWeb.UserSocket do
  use Phoenix.Socket

  ## Channels
  channel "user:*", FlowApiWeb.UserChannel

  @doc """
  Connect to the socket with JWT token authentication.
  Token is passed as a query parameter: ?token={jwt_token}
  """
  def connect(%{"token" => token}, socket, _connect_info) do
    case FlowApi.Guardian.decode_and_verify(token) do
      {:ok, claims} ->
        case FlowApi.Guardian.resource_from_claims(claims) do
          {:ok, user} ->
            {:ok, assign(socket, :user_id, user.id)}

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
end
