defmodule CoreWeb.Plugs.LoadActorFromToken do
  @moduledoc """
  Authentication plug that loads the actor (user) from a bearer token.

  This plug checks for an Authorization header with a bearer token,
  validates it, and sets the actor in the connection assigns for Ash policies.

  ## Usage

      plug CoreWeb.Plugs.LoadActorFromToken

  ## Token Format

  For now, we use a simple JWT format. In production, this will be replaced
  with proper JWT validation using AshAuthentication tokens.

  ## Examples

      # Valid request
      GET /api/v1/assets
      Authorization: Bearer eyJhbGciOiJIUzI1NiJ9...

      # Sets actor in conn.assigns[:actor]
  """

  import Plug.Conn
  require Logger

  @doc false
  def init(opts), do: opts

  @doc false
  def call(conn, _opts) do
    # Get the authorization header
    case get_req_header(conn, "authorization") do
      ["Bearer " <> token] ->
        # Validate and load user from token
        case load_user_from_token(token) do
          {:ok, user} ->
            # Set actor for Ash policies
            conn
            |> assign(:actor, user)
            |> put_private(:ash_actor, user)

          {:error, :invalid_token} ->
            conn
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: "Invalid or expired token"})
            |> halt()

          {:error, :user_not_found} ->
            conn
            |> put_status(:unauthorized)
            |> Phoenix.Controller.json(%{error: "User not found"})
            |> halt()
        end

      _ ->
        # No token provided - continue without actor
        # (Policies will deny access if actor is required)
        conn
    end
  end

  defp load_user_from_token(token) do
    try do
      # Decode JWT (simple validation for now)
      case verify_jwt(token) do
        {:ok, claims} when is_map(claims) ->
          # Extract user_id from claims
          user_id = get_in(claims, ["sub"])
          if user_id do
            # Load user from database
            case Ash.read(Core.Accounts.User,
              filter: [id: user_id],
              authorize?: false
            ) do
              {:ok, [user]} ->
                {:ok, user}

              {:ok, []} ->
                {:error, :user_not_found}

              {:error, _error} ->
                {:error, :invalid_token}
            end
          else
            {:error, :invalid_token}
          end

        {:error, _reason} ->
          {:error, :invalid_token}
      end
    rescue
      _ ->
        {:error, :invalid_token}
    end
  end

  # Simple JWT verification - will be replaced with proper JWT library
  defp verify_jwt(token) do
    # For now, just do basic validation without signature verification
    # In production, use proper JWT validation with Joken or similar
    case String.split(token, ".") do
      [_header, payload, _signature] ->
        # Decode header and payload
        case decode_base64url(payload) do
          {:ok, payload_json} ->
            case Jason.decode(payload_json) do
              {:ok, claims} ->
                # Check expiration
                check_expiration(claims)

              {:error, _} ->
                {:error, :invalid_json}
            end

          {:error, _} ->
            {:error, :invalid_base64}
        end

      _ ->
        {:error, :invalid_format}
    end
  end

  defp check_expiration(claims) do
    case get_in(claims, ["exp"]) do
      nil ->
        # No expiration - accept
        {:ok, claims}

      exp when is_number(exp) ->
        # Compare with current time
        now = System.system_time(:second)
        if exp > now do
          {:ok, claims}
        else
          {:error, :expired}
        end

      _ ->
        {:ok, claims}
    end
  end

  defp decode_base64url(data) do
    # Add padding if needed
    padded = case rem(String.length(data), 4) do
      0 -> data
      r -> data <> String.duplicate("=", 4 - r)
    end

    case Base.decode64(padded) do
      {:ok, decoded} ->
        {:ok, decoded}

      :error ->
        # Try URL-safe base64
        case Base.url_decode64(padded) do
          {:ok, decoded} ->
            {:ok, decoded}

          :error ->
            {:error, :invalid_base64}
        end
    end
  end

  @doc """
  Generate a simple test token for a user.

  This is a simplified JWT generator for testing.
  In production, use proper JWT libraries.
  """
  def generate_test_token(user_id, expires_in_seconds \\ 3600) do
    now = System.system_time(:second)
    exp = now + expires_in_seconds

    claims = %{
      "sub" => user_id,
      "iat" => now,
      "exp" => exp,
      "typ" => "Bearer"
    }

    header = %{
      "alg" => "HS256",
      "typ" => "JWT"
    }

    encoded_header = encode_base64url(Jason.encode!(header))
    encoded_claims = encode_base64url(Jason.encode!(claims))

    # For now, just create unsigned token (for testing only!)
    "#{encoded_header}.#{encoded_claims}."
  end

  defp encode_base64url(data) do
    data
    |> Base.url_encode64(false)
  end
end
