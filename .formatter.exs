# Used by "mix format"
[
  import_deps: [:ecto, :phoenix],
  inputs: ["*.{ex,exs}", "priv/*/seeds.exs", "{config,lib,test}/**/*.{ex,exs}"],
  subdirectories: ["priv/*/migrations"],
  plugins: [Phoenix.LiveView.HTMLFormatter],
  line_length: 120,
  export: [
    locals_without_parens: [magic_auth: 1, magic_auth: 2]
  ]
]
