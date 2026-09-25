defmodule MagicAuth.Session do
  @moduledoc """
  Ecto schema representing user sessions.

  This module defines the data structure for user sessions, including the user's email and the session token.
  It also provides functions to generate session tokens and verify them.
  """
  use Ecto.Schema
  import Ecto.Query
  import Ecto.Changeset

  @rand_size 32

  schema "magic_auth_sessions" do
    field :email, :string
    field :token, :binary, redact: true
    field :user_id, :integer
    field :last_active_at, :utc_datetime
    field :last_ip, :string
    field :user_agent, :string

    timestamps(type: :utc_datetime)
  end

  @doc """
  Generates a token that will be stored in a signed place,
  such as session or cookie. As they are signed, those
  tokens do not need to be hashed.

  The reason why we store session tokens in the database, even
  though Phoenix already provides a session cookie, is because
  Phoenix' default session cookies are not persisted, they are
  simply signed and potentially encrypted. This means they are
  valid indefinitely, unless you change the signing/encryption
  salt.

  Therefore, storing them allows individual user
  sessions to be expired. The token system can also be extended
  to store additional data, such as the device used for logging in.
  You could then use this information to display all valid sessions
  and devices in the UI and allow users to explicitly expire any
  session they deem invalid.
  """
  def build_session(attrs) do
    attrs = Map.take(attrs, [:email, :user_id, :last_ip, :user_agent])

    %__MODULE__{}
    |> cast(attrs, [:email, :user_id, :last_ip, :user_agent])
    |> put_change(:token, :crypto.strong_rand_bytes(@rand_size))
    |> put_change(:last_active_at, DateTime.utc_now(:second))
    |> apply_changes()
  end

  @doc """
  Checks if the token is valid and returns its underlying lookup query.

  The query returns the user found by the token, if any.

  The token is valid if it matches the value in the database and it has
  not expired (after `session_validity_in_days`, counted from the log in or
  from the last activity, depending on `expiration`).
  """
  def verify_session_token_query(token, session_validity_in_days, expiration \\ :log_in) do
    query =
      from s in valid_sessions_query(session_validity_in_days, expiration),
        where: s.token == ^token

    {:ok, query}
  end

  @doc """
  Returns a query for the sessions that expired, according to `session_validity_in_days` and `expiration`.
  """
  def expired_sessions_query(session_validity_in_days, :log_in) do
    from s in __MODULE__, where: s.inserted_at <= ago(^session_validity_in_days, "day")
  end

  def expired_sessions_query(session_validity_in_days, :inactivity) do
    from s in __MODULE__, where: s.last_active_at <= ago(^session_validity_in_days, "day")
  end

  defp valid_sessions_query(session_validity_in_days, :log_in) do
    from s in __MODULE__, where: s.inserted_at > ago(^session_validity_in_days, "day")
  end

  defp valid_sessions_query(session_validity_in_days, :inactivity) do
    from s in __MODULE__, where: s.last_active_at > ago(^session_validity_in_days, "day")
  end
end
