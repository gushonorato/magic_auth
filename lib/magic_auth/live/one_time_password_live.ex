defmodule MagicAuth.OneTimePasswordLive do
  use Phoenix.LiveView
  alias Ecto.Changeset

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: changeset() |> to_form(as: "auth"))}
  end

  def changeset(attrs \\ %{}) do
    types = %{one_time_password: :string}

    {%{}, types}
    |> Changeset.cast(attrs, [:one_time_password])
    |> Changeset.validate_required([:one_time_password])
    |> Changeset.validate_length(:one_time_password,
      is: MagicAuth.Config.one_time_password_length(),
      message: "must be #{MagicAuth.Config.one_time_password_length()} digits"
    )
  end

  def handle_event("validate", attrs, socket) do
    {:noreply, socket |> assign(form: changeset(attrs) |> to_form(as: "auth"))}
  end

  def handle_event("verify", attrs, socket) do
    {:noreply, socket |> assign(form: changeset(attrs) |> to_form(as: "auth"))}
  end

  def one_time_password_form(assigns) do
    module = MagicAuth.Config.callback_module()
    apply(module, :one_time_password_form, [assigns])
  end

  def render(assigns) do
    ~H"""
    <.one_time_password_form form={@form} />
    """
  end
end
