import Config

if config_env() == :dev do
  config :mix_test_watch,
    exclude: [~r/test\/mix\/tasks\/magic_auth_install_test_output_files/]
end

if Mix.env() == :dev do
  esbuild = fn args ->
    [
      args: ~w(./js/magic_auth --bundle) ++ args,
      cd: Path.expand("../assets", __DIR__),
      env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
    ]
  end

  config :esbuild,
    version: "0.24.2",
    module: esbuild.(~w(--format=esm --sourcemap --outfile=../priv/static/magic_auth.esm.js)),
    main: esbuild.(~w(--format=cjs --sourcemap --outfile=../priv/static/magic_auth.cjs.js)),
    cdn:
      esbuild.(
        ~w(--format=iife --target=es2016 --global-name=MagicAuth --outfile=../priv/static/magic_auth.js)
      ),
    cdn_min:
      esbuild.(
        ~w(--format=iife --target=es2016 --global-name=MagicAuth --minify --outfile=../priv/static/magic_auth.min.js)
      )
end
