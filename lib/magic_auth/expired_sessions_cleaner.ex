defmodule MagicAuth.ExpiredSessionsCleaner do
  @moduledoc """
  Process that periodically deletes the expired sessions with `MagicAuth.delete_expired_sessions/0`.

  It's added to `MagicAuth.children/0` when `:delete_expired_sessions` is enabled:

  ```elixir
  config :magic_auth,
    delete_expired_sessions: true
  ```

  The expired sessions are deleted when the process starts and then once a day. In a cluster, each node runs its own process, which is harmless, as
  deleting sessions that were already deleted does nothing.
  """
  use GenServer

  require Logger

  @interval :timer.hours(24)

  def start_link(opts) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def init(_opts) do
    {:ok, nil, {:continue, :delete_expired_sessions}}
  end

  @impl true
  def handle_continue(:delete_expired_sessions, state) do
    delete_expired_sessions()
    {:noreply, state}
  end

  @impl true
  def handle_info(:delete_expired_sessions, state) do
    delete_expired_sessions()
    {:noreply, state}
  end

  defp delete_expired_sessions() do
    # Errors are logged instead of crashing the process. This process runs in the host's supervision tree, and
    # repeated crashes (e.g. while the database is unavailable) would exceed the restart intensity and take down the
    # host application.
    try do
      {count, nil} = MagicAuth.delete_expired_sessions()
      Logger.debug("Magic Auth deleted #{count} expired sessions")
    rescue
      exception ->
        Logger.error(
          "Magic Auth failed to delete expired sessions: " <> Exception.format(:error, exception, __STACKTRACE__)
        )
    end

    Process.send_after(self(), :delete_expired_sessions, @interval)
  end
end
