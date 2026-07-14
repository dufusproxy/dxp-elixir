defmodule CoreWeb.AuthController do
  @moduledoc """
  Authentication controller for login and token management.

  Provides endpoints for:
  - User login with email/password
  - Token generation for testing
  - Token refresh

  This is a simplified implementation for Milestone 5.
  Full authentication will be implemented with AshAuthentication in a future milestone.
  """

  use CoreWeb, :controller

  @doc """
  Login endpoint - accepts email/password and returns a test token.

  ## Parameters

    - email: User's email address
    - password: User's password

  ## Returns

    JSON with access_token if successful

  ## Examples

      POST /auth/login
      {
        "user": {
          "email": "user@example.com",
          "password": "password123"
        }
      }

  """
  def login(conn, %{"user" => %{"email" => email, "password" => password}}) do
    # Find user by email
    case Ash.read(Core.Accounts.User,
      filter: [email: email],
      authorize?: false
    ) do
      {:ok, [user]} ->
        # Verify password
        if verify_password(password, user.hashed_password) do
          # Generate token
          token = CoreWeb.Plugs.LoadActorFromToken.generate_test_token(user.id)

          json(conn, %{
            data: %{
              id: user.id,
              type: "user",
              attributes: %{
                email: user.email,
                name: user.name
              }
            },
            access_token: token,
            token_type: "Bearer",
            expires_in: 3600
          })
        else
          conn
          |> put_status(:unauthorized)
          |> json(%{error: "Invalid email or password"})
        end

      {:ok, []} ->
        conn
        |> put_status(:unauthorized)
        |> json(%{error: "Invalid email or password"})

      {:error, _error} ->
        conn
        |> put_status(:internal_server_error)
        |> json(%{error: "Database error"})
    end
  end

  def login(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing user credentials"})
  end

  @doc """
  Create a new user account.

  ## Parameters

    - user: User attributes (email, name, password, password_confirmation)

  ## Returns

    JSON with the created user and access token

  """
  def create(conn, %{"user" => user_params}) do
    case Ash.create(Core.Accounts.User, %{
      email: user_params["email"],
      name: user_params["name"],
      password: user_params["password"],
      password_confirmation: user_params["password_confirmation"]
    }, authorize?: false) do
      {:ok, user} ->
        # Generate token for immediate login
        token = CoreWeb.Plugs.LoadActorFromToken.generate_test_token(user.id)

        conn
        |> put_status(:created)
        |> json(%{
          data: %{
            id: user.id,
            type: "user",
            attributes: %{
              email: user.email,
              name: user.name
            }
          },
          access_token: token,
          token_type: "Bearer",
          expires_in: 3600
        })

      {:error, changeset} ->
        conn
        |> put_status(:unprocessable_entity)
        |> json(%{
          error: "Failed to create user",
          details: Ash.Error.to_ash_error(changeset)
        })
    end
  end

  def create(conn, _params) do
    conn
    |> put_status(:bad_request)
    |> json(%{error: "Missing user parameters"})
  end

  # Simple password verification - should match the User resource
  defp verify_password(password, hashed) do
    :crypto.hash(:sha256, password <> System.get_env("PASSWORD_SALT", "default_salt"))
    |> Base.encode64()
    |> case do
      ^hashed -> true
      _ -> false
    end
  end
end
