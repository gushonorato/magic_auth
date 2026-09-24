defmodule MagicAuth.PasswordLive do
  @moduledoc false

  use Phoenix.LiveView
  alias MagicAuth.{OneTimePassword, RateLimit}

  def mount(_params, _one_time_password, socket) do
    if connected?(socket) do
      :timer.send_interval(:timer.seconds(1), :update_countdown)
    end

    {:ok, assign(socket, form: to_password_form(nil), email: nil, error: nil)}
  end

  defp to_password_form(password), do: to_form(%{"password" => password}, as: "auth")

  def handle_params(params, _uri, socket) do
    case parse_email(params) do
      nil ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:log_in)
        {:noreply, push_navigate(socket, to: redirect_to)}

      email ->
        {:noreply, socket |> assign(email: email, error: parse_error(params)) |> assign_countdown()}
    end
  end

  defp parse_email(%{"email" => email}) when is_binary(email) and byte_size(email) > 0 do
    case String.match?(email, OneTimePassword.email_pattern()) do
      true -> email
      false -> nil
    end
  end

  defp parse_email(_params), do: nil

  defp parse_error(%{"error" => "invalid_code"}),
    do: MagicAuth.Config.callback_module().translate_error(:invalid_code, [])

  defp parse_error(%{"error" => "code_expired"}),
    do: MagicAuth.Config.callback_module().translate_error(:code_expired, [])

  defp parse_error(_params), do: nil

  def handle_event("verify", %{"auth" => %{"password" => password}}, socket) do
    password_str = password |> Enum.join("") |> String.trim()
    %{email: email} = socket.assigns

    if String.length(password_str) == MagicAuth.Config.one_time_password_length() do
      redirect_to = MagicAuth.Config.router().__magic_auth__(:verify, %{email: email, code: password_str})
      {:noreply, redirect(socket, to: redirect_to)}
    else
      {:noreply, assign(socket, form: to_password_form(password), error: nil)}
    end
  end

  def handle_event("resend_code", _params, socket) do
    %{email: email} = socket.assigns

    case MagicAuth.create_one_time_password(%{"email" => email}) do
      {:ok, _code, _one_time_password} ->
        message = MagicAuth.Config.callback_module().translate_error(:code_resent, [])
        socket = socket |> assign_countdown() |> put_flash(:info, message)
        {:noreply, socket}

      {:error, :rate_limited, countdown} ->
        error_message =
          MagicAuth.Config.callback_module().translate_error(:too_many_one_time_password_requests,
            countdown: countdown
          )

        {:noreply, put_flash(socket, :error, error_message)}
    end
  end

  def verify_form(assigns) do
    module = MagicAuth.Config.callback_module()
    apply(module, :verify_form, [assigns])
  end

  def render(assigns) do
    ~H"""
    <.verify_form
      form={@form}
      email={@email}
      error={@error}
      flash={@flash}
      countdown={@countdown}
      rate_limited?={@rate_limited?}
    />
    """
  end

  def handle_info(:update_countdown, socket), do: {:noreply, assign_countdown(socket)}

  defp assign_countdown(socket) do
    countdown = RateLimit.one_time_password_request_countdown(socket.assigns.email)
    assign(socket, countdown: countdown, rate_limited?: countdown > 0)
  end
end
