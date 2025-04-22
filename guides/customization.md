# Customization

The generator will create a file at `lib/my_app_web/magic_auth.ex` (or at `apps/my_app_web/lib/my_app_web/magic_auth.ex` in an umbrella project). This file contains several callbacks that you can modify to match your application's needs. It is filled with comprehensive comments that guide you through customizing both the appearance and behavior of Magic Auth. For detailed instructions, please refer to the comments in the generated file. Below is a brief explanation of what can be customized:

- The log in form appearance by modifying `log_in_form/1`.
- The verification form appearance by modifying `verify_form/1`.
- E-mail templates by modifying `one_time_password_requested/1`, `text_email_body/1`, and `html_email_body/1`.
- Access control logic by modifying `log_in_requested/1`.
- Error message translations by modifying `translate_error/1`.