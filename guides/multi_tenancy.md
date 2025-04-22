# Multi-tenant applications

Magic Auth provides robust support for multi-tenancy, accommodating both [foreign keys](https://hexdocs.pm/ecto/multi-tenancy-with-foreign-keys.html) and [query prefixes](https://hexdocs.pm/ecto/multi-tenancy-with-query-prefixes.html) strategies. This flexibility allows developers to choose the approach that best fits their application's architecture and requirements.

## Multi-tenancy with Foreign Keys

Assuming you followed the Ecto guide on multi-tenancy, your repo should look like this:

```elixir
defmodule MyApp.Repo do
  use Ecto.Repo, otp_app: :my_app

  require Ecto.Query

  @impl true
  def prepare_query(_operation, query, opts) do
    cond do
      opts[:skip_org_id] || opts[:ecto_query] in [:schema_migration, :preload] ->
        {query, opts}

      org_id = opts[:org_id] ->
        {Ecto.Query.where(query, org_id: ^org_id), opts}

      true ->
        raise "expected org_id or skip_org_id to be set"
    end
  end
end
```

You can modify the first condition of your `cond` clause to include `opts[:magic_auth]` like this:

```elixir
opts[:magic_auth] || opts[:skip_org_id] || opts[:ecto_query] in [:schema_migration, :preload] ->
  {query, opts}
end
```

Alternatively, if you prefer not to modify your `Repo`, you can configure Magic Auth to pass `skip_org_id: true` in
all queries using the `:repo_opts` configuration:

```elixir
# config/config.ex

config :magic_auth,
  repo_opts: [skip_org_id: true]
```

## Multi-tenancy with Query prefixes

You can dynamically set the database prefix by passing a function to the `:repo_opts` configuration:

```elixir
# config/config.exs
config :magic_auth,
  repo_opts: fn ->
    [prefix: Process.get({MyApp.Repo, :org_id})]
  end
```