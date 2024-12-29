defmodule MagicAuth.LoginLive do
  use Phoenix.LiveView

  alias Ecto.Changeset

  def mount(_params, _session, socket) do
    {:ok, assign(socket, email: "", submitted: false)}
  end

  def handle_event("validate", %{"email" => email}, socket) do
    form =
      %{email: email}
      |> changeset()
      |> Map.put(:action, :validate)
      |> to_form()

    {:noreply, assign(socket, form: form)}
  end

  def handle_event("login", %{"email" => _email}, socket) do
    {:noreply, assign(socket, submitted: true)}
  end

  def changeset(attrs) do
    types = %{email: :string}

    {%{}, types}
    |> Changeset.cast(attrs, [:email])
    |> Changeset.validate_required([:email])
    |> Changeset.validate_format(:email, ~r/^[^\s]+@[^\s]+$/, message: "must be a valid email")
  end

  def login_form(assigns) do
    module = Application.fetch_env!(:magic_auth, :ui_components)
    apply(module, :login_form, [assigns])
  end

  def render(assigns) do
    ~H"""
    <.login_form />
    """
  end
end
