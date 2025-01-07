Mox.defmock(MagicAuth.CallbacksMock, for: MagicAuth.Callbacks)

ExUnit.start()

MagicAuthTest.Repo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(MagicAuthTest.Repo, :manual)
