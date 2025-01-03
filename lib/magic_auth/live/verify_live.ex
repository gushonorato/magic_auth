defmodule MagicAuth.VerifyLive do
  use Phoenix.LiveView
  alias Ecto.Changeset

  def mount(_params, _session, socket) do
    {:ok, assign(socket, form: changeset() |> to_form(as: "auth"))}
  end

  def handle_params(params, _uri, socket) do
    {:noreply, assign(socket, email: params["email"])}
  end

  def handle_event("validate", attrs, socket) do
    {:noreply, socket |> assign(form: changeset(attrs) |> to_form(as: "auth"))}
  end

  def handle_event("verify", attrs, socket) do
    {:noreply, socket |> assign(form: changeset(attrs) |> to_form(as: "auth"))}
  end

  defp changeset(attrs \\ %{}) do
    types = %{code: :string}

    {%{}, types}
    |> Changeset.cast(attrs, [:code])
    |> Changeset.validate_required([:code])
    |> Changeset.validate_length(:code, is: MagicAuth.Config.one_time_password_length())
    |> Changeset.validate_format(:code, ~r/^[0-9]+$/, message: "deve conter apenas números")
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
