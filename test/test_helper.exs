Mox.defmock(MagicAuthTestWeb.CallbacksMock, for: MagicAuth.Callbacks)

Application.put_env(:magic_auth, :repo, MagicAuthTest.Repo)
Application.put_env(:magic_auth, :callbacks, MagicAuthTestWeb.CallbacksMock)
Application.put_env(:magic_auth, :router, MagicAuthTestWeb.Router)
Application.put_env(:magic_auth, :endpoint, MagicAuthTestWeb.Endpoint)
Application.put_env(:magic_auth, :remember_me_cookie, "_magic_auth_test_remember_me")
Application.put_env(:lero, :foo, "bar")

ExUnit.start()

MagicAuthTest.Repo.start_link()

Application.put_env(:magic_auth_test, MagicAuthTestWeb.Endpoint, [])
{:ok, _} = MagicAuthTestWeb.Endpoint.start_link()

Ecto.Adapters.SQL.Sandbox.mode(MagicAuthTest.Repo, :manual)
