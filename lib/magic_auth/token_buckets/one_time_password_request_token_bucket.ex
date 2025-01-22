defmodule MagicAuth.TokenBuckets.OneTimePasswordRequestTokenBucket do
  @moduledoc false

  # Token bucket to limit the number of one-time password (OTP) code requests per email.

  # Prevents abuse avoiding excessive email quota consumption by limiting the number
  # of code requests that can be sent to a given email address within a time interval.

  # By default, allows 1 requests per minute per email address.

  use MagicAuth.TokenBucket,
    tokens: 1,
    reset_interval: :timer.minutes(1)
end
