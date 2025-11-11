defmodule FlowApi.Repo do
  use Ecto.Repo,
    otp_app: :flow_api,
    adapter: Ecto.Adapters.Postgres
end
