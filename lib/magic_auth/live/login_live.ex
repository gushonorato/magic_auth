defmodule MagicAuth.LoginLive do
  use Phoenix.LiveView

  alias MagicAuth.Session

  defp to_auth_form(changeset) do
    to_form(changeset, as: "auth")
  end

  def mount(_params, _session, socket) do
    form = %Session{} |> Session.changeset(%{}) |> to_auth_form()
    {:ok, assign(socket, form: form)}
  end

  def handle_event("validate", %{"auth" => attrs}, socket) do
    form =
      %Session{}
      |> Session.changeset(attrs)
      |> Map.put(:action, :validate)
      |> to_auth_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("login", %{"auth" => attrs}, socket) do
    case MagicAuth.create_unauthenticated_session(attrs) do
      {:ok, _} ->
        {:noreply, push_navigate(socket, to: "/sessions/verify")}

      {:error, changeset} ->
        form = changeset |> Map.put(:action, :login) |> to_auth_form()
        {:noreply, assign(socket, form: form)}
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
