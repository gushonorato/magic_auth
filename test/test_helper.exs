Mox.defmock(MagicAuth.CallbacksMock, for: MagicAuth.Callbacks)

ExUnit.start()

MagicAuth.TestRepo.start_link()

Ecto.Adapters.SQL.Sandbox.mode(MagicAuth.TestRepo, :manual)
