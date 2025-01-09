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
        {:ok, _tref} = :timer.send_interval(config.reset_interval, :reset)
        {:ok, %{config: config}}
      end

      defdelegate handle_info(message, state), to: MagicAuth.TokenBucket

      def take(key), do: MagicAuth.TokenBucket.take(key, config())
      def get_tokens(key), do: MagicAuth.TokenBucket.get_tokens(key, config())
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

  def get_tokens(key, config) do
    case :ets.lookup(config.table_name, key) do
      [{^key, count}] -> count
      [] -> config.tokens
    end
  end

  def handle_info(:reset, state) do
    %{config: %{table_name: table_name}} = state
    reset(table_name)
    {:noreply, state}
  end

  def reset(table_name) do
    :ets.delete_all_objects(table_name)
  end
end
