defmodule FlowApiWeb.Channels.Presence do
  @moduledoc """
  Presence tracking for online users using Phoenix.Presence.
  """
  use Phoenix.Presence,
    otp_app: :flow_api,
    pubsub_server: FlowApi.PubSub
end
