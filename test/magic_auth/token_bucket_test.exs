defmodule MagicAuth.TokenBucketTest do
  use ExUnit.Case, async: false

  defmodule EmailTokenBucket do
    use MagicAuth.TokenBucket, tokens: 30, reset_interval: 1
  end

  defmodule LoginAttemptsTokenBucket do
    use MagicAuth.TokenBucket
  end

  setup do
    start_supervised!(EmailTokenBucket)
    start_supervised!(LoginAttemptsTokenBucket)
    :ok
  end

  test "EmailTokenBucket starts with 10 tokens" do
    assert EmailTokenBucket.count("test_key") == 30
  end

  test "LoginAttemptsTokenBucket starts with 30 tokens" do
    assert LoginAttemptsTokenBucket.count("test_key") == 10
  end

  test "EmailTokenBucket is configured with custom options" do
    assert EmailTokenBucket.config() == %{
             reset_interval: 1,
             table_name: MagicAuth.TokenBucketTest.EmailTokenBucket,
             tokens: 30
           }
  end

  test "LoginAttemptsTokenBucket is configured with default options" do
    assert LoginAttemptsTokenBucket.config() == %{
             reset_interval: :timer.minutes(1),
             table_name: MagicAuth.TokenBucketTest.LoginAttemptsTokenBucket,
             tokens: 10
           }
  end

  test "allows requests within the limit" do
    assert {:ok, 29} = EmailTokenBucket.take("test_key")
    assert {:ok, 28} = EmailTokenBucket.take("test_key")
    assert EmailTokenBucket.count("test_key") == 28
  end

  test "blocks requests after reaching the limit" do
    # Consume all tokens
    for _ <- 1..30 do
      assert {:ok, _} = EmailTokenBucket.take("test_key")
    end

    # Try one more request
    assert {:error, :rate_limited} = EmailTokenBucket.take("test_key")
    assert EmailTokenBucket.count("test_key") == 0
  end

  test "resets tokens after interval" do
    # Consume some tokens
    assert {:ok, 29} = EmailTokenBucket.take("test_key")
    assert EmailTokenBucket.count("test_key") == 29

    Process.send(EmailTokenBucket, :reset, [])
    Process.sleep(1)

    # Verify tokens were reset
    assert EmailTokenBucket.count("test_key") == 30
  end

  test "maintains separate counters for different keys" do
    assert {:ok, 29} = EmailTokenBucket.take("key1")
    assert {:ok, 29} = EmailTokenBucket.take("key2")

    assert EmailTokenBucket.count("key1") == 29
    assert EmailTokenBucket.count("key2") == 29
  end

  @tag :slow
  test "automatically resets after interval" do
    assert {:ok, 29} = EmailTokenBucket.take("test_key")

    # Wait slightly longer than the reset interval
    Process.sleep(10)

    # Verify tokens were reset
    assert EmailTokenBucket.count("test_key") == 30
  end

  test "subscribers receive countdown updates" do
    test_pid = self()

    # Cria múltiplos processos que se inscrevem para atualizações
    pids =
      for _i <- 1..3 do
        spawn_link(fn ->
          LoginAttemptsTokenBucket.subscribe()

          receive do
            {:countdown_updated, countdown} ->
              send(test_pid, {:received, self(), countdown})
          end
        end)
      end

    Process.sleep(1)

    send(LoginAttemptsTokenBucket, :update_countdown)

    countdown = :timer.minutes(1) - :timer.seconds(1)

    # Verifica se todos os processos receberam a atualização
    Enum.each(pids, fn pid ->
      assert_receive {:received, ^pid, ^countdown}
    end)
  end

  @tag :slow
  test "countdown is updated every second" do
    LoginAttemptsTokenBucket.subscribe()

    for _i <- 1..3 do
      # Wait slightly more than 1 second to receive the next update
      assert_receive {:countdown_updated, countdown}, 1100
      assert is_integer(countdown)
    end
  end
end
