defmodule MagicAuth.Callbacks do
  @callback login_form(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback one_time_password_form(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback on_one_time_password_requested(code :: String.t(), one_time_password :: %MagicAuth.Session{}) :: any
end
