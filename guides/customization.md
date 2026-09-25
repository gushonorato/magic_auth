# Customization

The generator will create a file at `lib/my_app_web/magic_auth.ex` (or at `apps/my_app_web/lib/my_app_web/magic_auth.ex` in an umbrella project). This file contains several callbacks that you can modify to match your application's needs. It is filled with comprehensive comments that guide you through customizing both the appearance and behavior of Magic Auth. For detailed instructions, please refer to the comments in the generated file. Below is a brief explanation of what can be customized:

- The log in form appearance by modifying `log_in_form/1`.
- The verification form appearance by modifying `verify_form/1`.
- E-mail templates by modifying `one_time_password_requested/1`, `text_email_body/1`, and `html_email_body/1`.
- Access control logic by modifying `log_in_requested/1`.
- Error message translations by modifying `translate_error/1`.
## Sending codes only to registered emails

By default, Magic Auth generates a code and calls `one_time_password_requested/1` for any email typed in the log in
form. Magic Auth doesn't know which emails are registered in your application, so this decision is made in your
callbacks module.

To send codes only to registered emails, skip the delivery in `one_time_password_requested/1` when the email isn't
registered. In this example, the delivery code generated in `one_time_password_requested/1` was moved to a private
`deliver_one_time_password/2` function:

```elixir
def one_time_password_requested(%{code: code, email: email}) do
  if allowed?(email) do
    Task.start(fn -> deliver_one_time_password(code, email) end)
  end
end

def log_in_requested(%{email: email}) do
  if allowed?(email), do: :allow, else: :deny
end

defp allowed?(email), do: Repo.exists?(from u in User, where: u.email == ^email)
```

A few details make this work safely:

- **The form doesn't reveal which emails are registered.** The user is redirected to the verification page whether
  the email was sent or not, and any code typed for an unregistered email is invalid. Use a neutral message on the
  verification page, such as "If this email is registered, you will receive a code", by changing `verify_form/1`.
- **Deliver the email in the background.** When the delivery runs in the request, the response for registered emails
  takes longer, as it waits for the email service, and measuring it reveals which emails are registered. Deliver it
  with `Task.start/1`, as above, or with a job queue such as [Oban](https://hexdocs.pm/oban) for retries.
- **Use the same rule in both callbacks.** `log_in_requested/1` still runs after the code is verified, and denies the
  log in if the email isn't allowed. Sharing a function such as `allowed?/1` keeps both callbacks consistent.

The code is still stored in the database for unregistered emails. It expires after `one_time_password_expiration`
minutes (default: 10) and is replaced by the next code requested for the same email.
