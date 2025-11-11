defmodule FlowApiWeb.AuthPipeline do
  use Guardian.Plug.Pipeline,
    otp_app: :flow_api,
    module: FlowApi.Guardian,
    error_handler: FlowApiWeb.AuthErrorHandler

  plug Guardian.Plug.VerifyHeader, scheme: "Bearer"
  plug Guardian.Plug.EnsureAuthenticated
  plug Guardian.Plug.LoadResource
end
