defmodule FlowApi.Accounts do
  @moduledoc """
  The Accounts context handles user authentication and management.
  """

  import Ecto.Query
  alias FlowApi.Repo
  alias FlowApi.Accounts.User

  # User CRUD
  def list_users, do: Repo.all(User)

  def get_user(id), do: Repo.get(User, id)

  def get_user!(id), do: Repo.get!(User, id)

  def get_user_by_email(email), do: Repo.get_by(User, email: email)

  def create_user(attrs \\ %{}) do
    %User{}
    |> User.changeset(attrs)
    |> Repo.insert()
  end

  def update_user(%User{} = user, attrs) do
    user
    |> User.changeset(attrs)
    |> Repo.update()
  end

  def delete_user(%User{} = user), do: Repo.delete(user)

  # Authentication
  def authenticate_user(email, password) do
    user = get_user_by_email(email)

    cond do
      user && Bcrypt.verify_pass(password, user.password_hash) ->
        {:ok, user}
      user ->
        {:error, :unauthorized}
      true ->
        Bcrypt.no_user_verify()
        {:error, :unauthorized}
    end
  end

  def update_last_login(%User{} = user) do
    user
    |> Ecto.Changeset.change(last_login_at: DateTime.utc_now() |> DateTime.truncate(:second))
    |> Repo.update()
  end
end
