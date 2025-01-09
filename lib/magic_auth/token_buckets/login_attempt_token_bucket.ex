defmodule MagicAuth.TokenBuckets.LoginAttemptTokenBucket do
  @moduledoc """
  Token bucket to limit the number of login attempts per email.

  Prevents brute force attacks by limiting the number of code verification
  attempts that can be made for a given email address within a time interval.

  By default, allows max 10 attempts every 10 minutes per email address.
  """

  use MagicAuth.TokenBucket,
    tokens: 10,
    reset_interval: :timer.minutes(10)
end
