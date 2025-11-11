defmodule FlowApiWeb.AuthController do
  use FlowApiWeb, :controller

  alias FlowApi.Accounts
  alias FlowApi.Guardian

  def login(conn, %{"email" => email, "password" => password}) do
    case Accounts.authenticate_user(email, password) do
      {:ok, user} ->
        {:ok, access_token, _claims} = Guardian.encode_and_sign(user, %{}, ttl: {1, :hour})
        {:ok, refresh_token, _claims} = Guardian.encode_and_sign(user, %{}, token_type: "refresh", ttl: {7, :days})

        Accounts.update_last_login(user)

        conn
        |> put_status(:ok)
        |> json(%{
          user: user_json(user),
          token: access_token,
          refresh_token: refresh_token
        })

      {:error, :unauthorized} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "UNAUTHORIZED", message: "Invalid email or password"}})
    end
  end

  def logout(conn, _params) do
    # TODO: Invalidate refresh token
    conn
    |> put_status(:ok)
    |> json(%{success: true})
  end

  def refresh(conn, %{"refresh_token" => refresh_token}) do
    case Guardian.exchange(refresh_token, "refresh", "access", ttl: {1, :hour}) do
      {:ok, _old, {new_access, _claims}} ->
        {:ok, new_refresh, _claims} = Guardian.exchange(refresh_token, "refresh", "refresh", ttl: {7, :days})

        conn
        |> put_status(:ok)
        |> json(%{token: new_access, refresh_token: new_refresh})

      {:error, _reason} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: %{code: "UNAUTHORIZED", message: "Invalid refresh token"}})
    end
  end

  def current_user(conn, _params) do
    user = Guardian.Plug.current_resource(conn)

    conn
    |> put_status(:ok)
    |> json(%{data: user_json(user)})
  end

  defp user_json(user) do
    %{
      id: user.id,
      email: user.email,
      name: user.name,
      avatar_url: user.avatar_url,
      role: user.role,
      preferences: %{
        theme: user.theme,
        notifications: user.notifications_enabled,
        timezone: user.timezone
      },
      created_at: user.inserted_at,
      last_login: user.last_login_at
    }
  end
end
