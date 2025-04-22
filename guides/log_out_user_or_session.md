# Log out user or session

Magic Auth provides several methods to log out users from their sessions. This guide explains how to implement logout functionality in your application, including logging out from a single session or all sessions simultaneously. You'll learn how to create logout links in both regular views and LiveViews, ensuring your users can securely end their sessions when needed.

## Creating a log out link

After setting up authentication, you must provide users with a way to log out. Magic Auth provides helper functions to generate the correct path for this action:

```elixir
<.link method="delete" href={~p"/sessions/log_out"}>Logout</.link>
```

## Logging out from all sessions

Magic Auth allows users to log out from all active sessions across all devices. This is useful for security purposes when a user suspects unauthorized access to their account.

To create a link that logs out from all sessions, use the following code:

```elixir
<.link method="delete" href={~p"/sessions/log_out/all"}>Logout</.link>
```

## Logging out from a LiveView

Since it's not possible to redirect to a route that accepts the DELETE method, Magic Auth alternatively creates a route to log out from all sessions using a GET method so it can be used within a LiveView event. For all other cases, you must use the DELETE method for logging out of sessions. Using the GET method to remove sessions indiscriminately, such as in `<.links>`, can cause incorrect behavior of your web application.

```elixir
def handle_event("save", _params, socket) do 
  {:noreply, redirect(socket, to: ~p"/sessions/log_out/all/get")}
end
```

If you want to log out from all sessions

See all generated routes in [Introspection Functions](/magic_auth/MagicAuth.Router.html#module-introspection-functions) section of the `MagicAuth.Router` documentation.

## Security considerations when email changes

When a user changes their email address, it's important to invalidate all existing sessions to ensure security and verify the new email is valid. This practice helps:

1. Confirm the user has access to the new email address by requiring them to log in again
2. Prevent unauthorized access if the email change was malicious

Here's how to implement this in your application:

```
MagicAuth.log_out_all(conn)
```

If you are using a LiveView-based form to update a user's email, you won't have access to the `conn` struct. In this case, you can use `MagicAuth.log_out_all/3` instead.

```
# Don't disconnect self or you'll be unable to redirect the current session to the login screen
MagicAuth.log_out_all(user, session, disconnect_self: false)

# Don't forget to redirect the current LiveView to the login screen after log out all
redirect(socket, to: destination)
```
