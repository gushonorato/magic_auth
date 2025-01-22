defmodule MagicAuth.MixProject do
  use Mix.Project

  @version "0.1.0"
  @scm_url "https://github.com/gushonorato/magic_auth"

  def project do
    [
      app: :magic_auth,
      version: @version,
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      docs: docs(),
      package: package(),
      description: "An Elixir authentication library designed for effortless setup",
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      # {:dep_from_hexpm, "~> 0.3.0"},
      # {:dep_from_git, git: "https://github.com/elixir-lang/my_dep.git", tag: "0.1.0"}
      {:phoenix_live_view, "~> 1.0"},
      {:phoenix, "~> 1.7"},
      {:ecto, "~> 3.10"},
      {:ecto_sql, "~> 3.10", only: [:dev, :test]},
      {:postgrex, ">= 0.0.0"},
      {:mix_test_watch, "~> 1.2", only: [:dev], runtime: false},
      {:bcrypt_elixir, "~> 3.1"},
      {:mox, "~> 1.0", only: :test},
      {:ex_doc, "~> 0.34", only: :dev, runtime: false}
    ]
  end

  defp docs do
    [
      source_ref: "v#{@version}",
      assets: %{"guides/assets" => "assets"},
      main: "getting_started",
      extras: [
        "guides/getting_started.md",
        "CHANGELOG.md",
        "LICENSE.md"
      ]
    ]
  end

  defp package do
    [
      maintainers: ["Gustavo Honorato"],
      licenses: ["MIT"],
      links: %{"GitHub" => @scm_url},
      files: ~w(assets/js lib priv CHANGELOG.md LICENSE.md mix.exs package.json README.md .formatter.exs)
    ]
  end
end
