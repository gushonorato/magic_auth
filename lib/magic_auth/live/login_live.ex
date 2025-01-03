defmodule MagicAuth.LoginLive do
  use Phoenix.LiveView

  alias MagicAuth.OneTimePassword

  defp to_auth_form(changeset) do
    to_form(changeset, as: "auth")
  end

  def mount(_params, _session, socket) do
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
    case MagicAuth.generate_one_time_password(attrs) do
      {:ok, _} ->
        {:noreply, push_navigate(socket, to: "/sessions/verify")}

      {:error, changeset} ->
        dbg(changeset)
        {:noreply, assign(socket, form: to_auth_form(changeset))}
    end
  end

  def login_form(assigns) do
    module = MagicAuth.Config.callback_module()
    apply(module, :login_form, [assigns])
  end

  def render(assigns) do
    ~H"""
    <.login_form form={@form} />
    """
  end
end
