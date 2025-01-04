defmodule MagicAuth.PasswordLive do
  use Phoenix.LiveView
  alias MagicAuth.Session

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: to_password_form(nil), email: nil, error: nil)}
  end

  defp to_password_form(password), do: to_form(%{"password" => password}, as: "auth")

  def handle_params(params, _uri, socket) do
    dbg(params)

    case parse_email(params) do
      nil ->
        redirect_to = MagicAuth.Config.router().__magic_auth__(:login)
        {:noreply, push_navigate(socket, to: redirect_to)}

      email ->
        {:noreply, assign(socket, email: email, error: parse_error(params))}
    end
  end

  defp parse_email(%{"email" => email}) when is_binary(email) and byte_size(email) > 0 do
    case String.match?(email, Session.email_pattern()) do
      true -> email
      false -> nil
    end
  end

  defp parse_email(_params), do: nil

  defp parse_error(%{"error" => "invalid_code"}), do: "Invalid code"
  defp parse_error(%{"error" => "code_expired"}), do: "Code expired"
  defp parse_error(_params), do: nil

  def handle_event("verify", %{"auth" => %{"password" => password}}, socket) do
    password_str = password |> Enum.join("") |> String.trim()
    %{email: email} = socket.assigns

    if String.length(password_str) == MagicAuth.Config.one_time_password_length() do
      case MagicAuth.verify_password(email, password_str) do
        {:error, :invalid_code} ->
          {:noreply, assign(socket, error: "Invalid code", password: to_password_form(nil))}

        {:error, :code_expired} ->
          {:noreply, assign(socket, error: "Code expired", password: to_password_form(nil))}

        {:ok, _session} ->
          redirect_to = MagicAuth.Config.router().__magic_auth__(:password, %{email: email})
          {:noreply, push_navigate(socket, to: redirect_to)}
      end
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
    <.verify_form form={@form} email={@email} error={@error} />
    """
  end
end
