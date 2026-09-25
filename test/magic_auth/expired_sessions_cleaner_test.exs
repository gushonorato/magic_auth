defmodule MagicAuth.ExpiredSessionsCleanerTest do
  use MagicAuth.DataCase, async: false

  import ExUnit.CaptureLog
  import MagicAuthTest.Helpers

  alias MagicAuth.{ExpiredSessionsCleaner, Session}

  setup :preserve_app_env

  defmodule FakeEndpoint do
    def broadcast(_socket_id, _event, _payload), do: :ok
  end

  defmodule FailingRepo do
    def delete_all(_query, _opts), do: raise("database unavailable")
  end

  setup do
    Application.put_env(:magic_auth, :endpoint, FakeEndpoint)
    :ok
  end

  defp create_expired_session!() do
    %{email: "user@example.com"}
    |> MagicAuth.create_session!()
    |> Ecto.Changeset.change(inserted_at: DateTime.add(DateTime.utc_now(:second), -61, :day))
    |> MagicAuthTest.Repo.update!()
  end

  describe "MagicAuth.children/0" do
    test "does not include the cleaner by default" do
      refute ExpiredSessionsCleaner in MagicAuth.children()
    end

    test "includes the cleaner when delete_expired_sessions is enabled" do
      Application.put_env(:magic_auth, :delete_expired_sessions, true)
      assert ExpiredSessionsCleaner in MagicAuth.children()
    end
  end

  test "deletes the expired sessions when started" do
    expired_session = create_expired_session!()
    valid_session = MagicAuth.create_session!(%{email: "user@example.com"})

    pid = start_supervised!(ExpiredSessionsCleaner)
    :sys.get_state(pid)

    refute MagicAuthTest.Repo.get(Session, expired_session.id)
    assert MagicAuthTest.Repo.get(Session, valid_session.id)
  end

  test "deletes the expired sessions periodically" do
    pid = start_supervised!(ExpiredSessionsCleaner)
    :sys.get_state(pid)

    expired_session = create_expired_session!()
    send(pid, :delete_expired_sessions)
    :sys.get_state(pid)

    refute MagicAuthTest.Repo.get(Session, expired_session.id)
  end

  test "logs the error and keeps running when the deletion fails" do
    Application.put_env(:magic_auth, :repo, FailingRepo)

    log =
      capture_log(fn ->
        pid = start_supervised!(ExpiredSessionsCleaner)
        :sys.get_state(pid)

        send(pid, :delete_expired_sessions)
        :sys.get_state(pid)

        assert Process.alive?(pid)
      end)

    assert log =~ "Magic Auth failed to delete expired sessions"
    assert log =~ "database unavailable"
  end
end
