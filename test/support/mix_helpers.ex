defmodule MAgicAuthTest.MixHelpers do
  def tmp_path do
    Path.expand("../../tmp", __DIR__)
  end

  defp random_string(len) do
    len |> :crypto.strong_rand_bytes() |> Base.url_encode64() |> binary_part(0, len)
  end

  def use_tmp_dir() do
    tmp_dir = Path.join([tmp_path(), random_string(10)])

    File.rm_rf!(tmp_dir)
    File.mkdir_p!(tmp_dir)

    previous_dir = File.cwd!()
    File.cd!(tmp_dir)
    {previous_dir, tmp_dir}
  end

  def teardown_tmp_dir({previous_dir, tmp_dir}) do
    File.cd!(previous_dir)
    File.rm_rf!(tmp_dir)
  end
end
