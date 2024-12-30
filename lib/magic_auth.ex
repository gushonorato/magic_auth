defmodule MagicAuth do
  @moduledoc """
  Documentation for `MagicAuth`.
  """

  def otp_length do
    Application.get_env(:magic_auth, :otp_length, 6)
  end
end
