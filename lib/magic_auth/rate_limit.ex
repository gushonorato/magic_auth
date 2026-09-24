defmodule MagicAuth.RateLimit do
  @moduledoc false

  # Rate limits applied per email address, backed by Hammer.

  # Emails are downcased before being used as keys. The email columns are citext, so
  # "user@example.com" and "USER@example.com" refer to the same one-time password. Without
  # the normalization, each case variation would get its own limit, allowing an attacker
  # to bypass it.

  # Each email has its own window, which starts on its first hit. This avoids resetting the
  # limits of every email at the same moment.
  use Hammer, backend: :ets, algorithm: :fix_window_per_key

  # Prevents abuse avoiding excessive email quota consumption by limiting the number
  # of code requests that can be sent to a given email address within a time interval.
  # Allows 1 request per minute per email address.
  @one_time_password_request_scale :timer.minutes(1)
  @one_time_password_request_limit 1

  def check_one_time_password_request(email) do
    check(
      key(:one_time_password_request, email),
      @one_time_password_request_scale,
      @one_time_password_request_limit
    )
  end

  def one_time_password_request_countdown(email) do
    countdown(
      key(:one_time_password_request, email),
      @one_time_password_request_scale,
      @one_time_password_request_limit
    )
  end

  defp key(action, email), do: {action, String.downcase(email)}

  defp check(key, scale, limit), do: check(key, scale, limit, MagicAuth.Config.rate_limit_enabled?())

  defp check(_key, _scale, _limit, false), do: :ok

  defp check(key, scale, limit, true) do
    case hit(key, scale, limit) do
      {:allow, _count} -> :ok
      {:deny, retry_after} -> {:error, :rate_limited, to_seconds(retry_after)}
    end
  end

  defp countdown(key, scale, limit) do
    case get(key, scale) >= limit do
      true -> to_seconds(expires_at(key, scale) - System.system_time(:millisecond))
      false -> 0
    end
  end

  # Rounds up, so the countdown only reaches zero when the limit is lifted.
  defp to_seconds(milliseconds), do: ceil(max(milliseconds, 0) / 1000)
end
