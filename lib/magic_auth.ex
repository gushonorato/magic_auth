defmodule MagicAuth do
  @moduledoc """
  Documentation for `MagicAuth`.
  """

  def one_time_password_length do
    Application.get_env(:magic_auth, :one_time_password_length, 6)
  end
end
