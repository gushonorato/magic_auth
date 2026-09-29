defmodule MagicAuth.Callbacks do
  @moduledoc false

  @callback log_in_form(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback verify_form(assigns :: map()) :: Phoenix.LiveView.Rendered.t()
  @callback page_title(page :: :log_in | :password) :: String.t() | nil
  @callback one_time_password_requested(data :: map()) :: any
  @callback log_in_requested(data :: map()) :: :deny | :allow | {:allow, user_id :: integer()}
  @callback translate_error(key :: atom(), opts :: keyword()) :: String.t()

  @optional_callbacks page_title: 1
end
