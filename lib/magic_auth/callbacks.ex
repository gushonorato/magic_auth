defmodule MagicAuth.Callbacks do
  @callback on_one_time_password_generated(code :: String.t(), one_time_password :: %MagicAuth.OneTimePassword{}) :: :ok
end
