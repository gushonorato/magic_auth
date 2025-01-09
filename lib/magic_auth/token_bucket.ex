defmodule MagicAuth.TokenBucket do
  defmacro __using__(config \\ []) do
    quote bind_quoted: [config: config] do
      use GenServer

      def config() do
        unquote(config)
        |> Keyword.validate!(
          table_name: unquote(__MODULE__),
          tokens: 10,
          reset_interval: :timer.minutes(1)
        )
        |> Enum.into(%{})
      end

      def start_link(_opts \\ []) do
        GenServer.start_link(unquote(__MODULE__), config(), name: unquote(__MODULE__))
      end

      def init(config) do
        :ets.new(config.table_name, [:set, :named_table, :public])
        {:ok, _reset_timer} = :timer.send_interval(config.reset_interval, :reset)
        {:ok, _countdown_timer} = :timer.send_interval(:timer.seconds(1), :update_countdown)
        {:ok, %{config: config, countdown: config.reset_interval, subscribers: []}}
      end

      defdelegate handle_info(message, state), to: MagicAuth.TokenBucket
      defdelegate handle_cast(message, state), to: MagicAuth.TokenBucket

      def subscribe(pid \\ self()), do: GenServer.cast(unquote(__MODULE__), {:subscribe, pid})
      def take(key), do: MagicAuth.TokenBucket.take(key, config())
      def count(key), do: MagicAuth.TokenBucket.count(key, config())
    end
  end

  def take(key, config) do
    case :ets.update_counter(config.table_name, key, -1, {key, config.tokens}) do
      count when count >= 0 ->
        {:ok, count}

      _ ->
        :ets.update_counter(config.table_name, key, 1, {key, 0})
        {:error, :rate_limited}
    end
  end

  def count(key, config) do
    case :ets.lookup(config.table_name, key) do
      [{^key, count}] -> count
      [] -> config.tokens
    end
  end

  def handle_info(:reset, state) do
    %{config: %{table_name: table_name}} = state
    :ets.delete_all_objects(table_name)

    {:noreply, %{state | countdown: state.config.reset_interval}}
  end

  def handle_info(:update_countdown, state) do
    countdown = state.countdown - :timer.seconds(1)

    Enum.each(state.subscribers, fn pid ->
      send(pid, {:countdown_updated, countdown})
    end)

    {:noreply, %{state | countdown: countdown}}
  end

  def handle_cast({:subscribe, called_pid}, state) do
    {:noreply, %{state | subscribers: [called_pid | state.subscribers]}}
  end
end
