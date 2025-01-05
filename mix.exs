defmodule MagicAuth.MixProject do
  use Mix.Project

  def project do
    [
      app: :magic_auth,
      version: "0.1.0",
      elixir: "~> 1.17",
      elixirc_paths: elixirc_paths(Mix.env()),
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:mox, "~> 1.0", only: :test}
    ]
  end
end
