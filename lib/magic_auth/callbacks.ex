defmodule MagicAuth.Callbacks do
  @callback log_in_form(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback verify_form(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback one_time_password_requested(data :: map()) :: any
  @callback log_in_requested(data :: map()) :: :deny | :allow
  @callback translate_error(key :: atom(), opts :: keyword()) :: String.t()
end
