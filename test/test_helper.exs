Mox.defmock(MagicAuth.CallbacksMock, for: MagicAuth.Callbacks)

ExUnit.start()

MagicAuthTest.Repo.start_link()

Application.put_env(:magic_auth_test, MagicAuthTestWeb.Endpoint, [])
{:ok, _} = MagicAuthTestWeb.Endpoint.start_link()

Ecto.Adapters.SQL.Sandbox.mode(MagicAuthTest.Repo, :manual)
