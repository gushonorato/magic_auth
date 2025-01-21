defmodule MagicAuthTest.Helpers do
  def tmp_path do
    Path.expand("../../tmp", __DIR__)
  end

  defp random_string(len) do
    len |> :crypto.strong_rand_bytes() |> Base.url_encode64() |> binary_part(0, len)
  end

  def use_tmp_dir(_opts) do
    {previous_dir, tmp_dir} = create_tmp_dir()
    ExUnit.Callbacks.on_exit(fn -> teardown_tmp_dir({previous_dir, tmp_dir}) end)
    :ok
  end

  defp create_tmp_dir() do
    tmp_dir = Path.join([tmp_path(), random_string(10)])

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    previous_dir = File.cwd!()
    File.cd!(tmp_dir)
    {previous_dir, tmp_dir}
  end

  defp teardown_tmp_dir({previous_dir, tmp_dir}) do
    File.cd!(previous_dir)
    File.rm_rf!(tmp_dir)
  end

  def config_sandbox(fun) do
    previous_envs = Application.get_all_env(:magic_auth)

    try do
      fun.()
    after
      restore_envs(previous_envs)
    end
  end

  def preserve_app_env(_opts) do
    previous_envs = Application.get_all_env(:magic_auth)
    ExUnit.Callbacks.on_exit(fn -> restore_envs(previous_envs) end)
  end

  defp restore_envs(previous_envs) do
    :magic_auth
    |> Application.get_all_env()
    |> Enum.each(fn {key, _value} -> Application.delete_env(:magic_auth, key) end)

    Application.put_all_env([{:magic_auth, previous_envs}])
  end
end
