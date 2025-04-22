# Testing 

To test routes that require authentication in your Phoenix application, utilize the `MagicAuth.TestHelpers.log_in_session/2` function as demonstrated below:

```
defmodule MyApp.MyModuleTest do
  use MyApp.ConnCase, async: true
  import MagicAuth.TestHelpers

  setup do
    conn = build_conn() |> Plug.Test.init_test_session(%{})
    %{conn: conn}
  end

  test "creates a session and puts token in session", %{conn: conn} do
    params = %{email: "test@example.com"}
    conn = log_in_session(conn, params)
    # Test assertions
  end
end
```

Remember to disable rate limiting in your test environment to prevent test failures.

```
# config/test.exs
config :magic_auth,
  enable_rate_limit: false
```