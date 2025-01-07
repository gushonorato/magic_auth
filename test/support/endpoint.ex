defmodule MagicAuthTestWeb.ErrorView do
  def render("404.html", _assigns) do
    "Página não encontrada"
  end

  def render("500.html", _assigns) do
    "Erro interno do servidor"
  end

  def template_not_found(_template, _assigns) do
    "Erro interno do servidor"
  end
end

defmodule MagicAuthTestWeb.Endpoint do
  use Phoenix.Endpoint, otp_app: :magic_auth

  # Configurações básicas para testes
  @session_options [
    store: :cookie,
    key: "_magic_auth_test_key",
    signing_salt: "teste123"
  ]

  plug Plug.Session, @session_options

  plug Plug.Parsers,
    parsers: [:urlencoded, :multipart],
    pass: ["*/*"]

  plug MagicAuthTestWeb.Router
end
