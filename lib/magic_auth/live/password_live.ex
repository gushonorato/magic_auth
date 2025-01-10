defmodule MagicAuth.PasswordLive do
  use Phoenix.LiveView
  alias MagicAuth.OneTimePassword
  alias MagicAuth.TokenBuckets.OneTimePasswordRequestTokenBucket

  def mount(_params, _one_time_password, socket) do
    if connected?(socket) do
      OneTimePasswordRequestTokenBucket.subscribe()
    end

    {:ok,
     assign(socket,
       form: to_password_form(nil),
       email: nil,
       error: nil,
       countdown: OneTimePasswordRequestTokenBucket.get_countdown()
     )}
  end

  defp to_password_form(password), do: to_form(%{"password" => password}, as: "auth")

  def handle_params(params, _uri, socket) do
    case parse_email(params) do
      nil ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:log_in)
        {:noreply, push_navigate(socket, to: redirect_to)}

      email ->
        {:noreply, assign(socket, email: email, error: parse_error(params))}
    end
  end

  defp parse_email(%{"email" => email}) when is_binary(email) and byte_size(email) > 0 do
    case String.match?(email, OneTimePassword.email_pattern()) do
      true -> email
      false -> nil
    end
  end

  defp parse_email(_params), do: nil

  defp parse_error(%{"error" => "invalid_code"}), do: MagicAuth.Config.callback_module().translate_error(:invalid_code)
  defp parse_error(%{"error" => "code_expired"}), do: MagicAuth.Config.callback_module().translate_error(:code_expired)
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

  def verify_form(assigns) do
    module = MagicAuth.Config.callback_module()
    apply(module, :verify_form, [assigns])
  end

  def render(assigns) do
    ~H"""
    <.verify_form form={@form} email={@email} error={@error} flash={@flash} countdown={@countdown} />
    """
  end

  def handle_info({:countdown_updated, countdown}, socket) do
    {:noreply, assign(socket, countdown: countdown)}
  end
end
