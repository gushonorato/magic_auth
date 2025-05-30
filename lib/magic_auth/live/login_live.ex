defmodule MagicAuth.LoginLive do
  @moduledoc false

  use Phoenix.LiveView

  alias MagicAuth.OneTimePassword

  defp to_auth_form(changeset) do
    to_form(changeset, as: "auth")
  end

  def mount(_params, _one_time_password, socket) do
    form = %OneTimePassword{} |> OneTimePassword.changeset(%{}) |> to_auth_form()
    {:ok, assign(socket, form: form)}
  end

  def handle_event("validate", %{"auth" => attrs}, socket) do
    form =
      %OneTimePassword{}
      |> OneTimePassword.changeset(attrs)
      |> Map.put(:action, :validate)
      |> to_auth_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("login", %{"auth" => attrs}, socket) do
    case MagicAuth.create_one_time_password(attrs) do
      {:ok, _code, one_time_password} ->
        path = MagicAuth.Config.router().__magic_auth__(:password, %{email: one_time_password.email})
        {:noreply, push_navigate(socket, to: path)}

      {:error, :rate_limited, countdown} ->
        error_message =
          MagicAuth.Config.callback_module().translate_error(:too_many_one_time_password_requests,
            countdown: countdown
          )

        {:noreply, put_flash(socket, :error, error_message)}

      {:error, changeset} ->
        form = changeset |> Map.put(:action, :log_in) |> to_auth_form()
        {:noreply, assign(socket, form: form)}
    end
  end

  def login_form(assigns) do
    module = MagicAuth.Config.callback_module()
    apply(module, :log_in_form, [assigns])
  end

  def render(assigns) do
    ~H"""
    <.login_form form={@form} flash={@flash} />
    """
  end
end
