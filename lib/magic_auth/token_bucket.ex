defmodule MagicAuth.TokenBucket do
  defmacro __using__(opts \\ []) do
    quote bind_quoted: [opts: opts] do
      use GenServer

      def opts() do
        unquote(opts)
        |> Keyword.validate!(
          table_name: unquote(__MODULE__),
          tokens: 10,
          reset_interval: :timer.minutes(1)
        )
        |> Enum.into(%{})
      end

      def start_link(_opts \\ []) do
        GenServer.start_link(unquote(__MODULE__), opts(), name: unquote(__MODULE__))
      end

      def init(opts) do
        :ets.new(opts.table_name, [:set, :named_table, :public])
        {:ok, _tref} = :timer.send_interval(opts.reset_interval, :reset)
        {:ok, opts}
      end

      def handle_info(:reset, state) do
        reset()
        {:noreply, state}
      end

      def take(key), do: MagicAuth.TokenBucket.take(key, opts())
      def get_tokens(key), do: MagicAuth.TokenBucket.get_tokens(key, opts())
      def reset, do: MagicAuth.TokenBucket.reset(opts())
    end
  end

  def take(key, opts) do
    case :ets.update_counter(opts.table_name, key, -1, {key, opts.tokens}) do
      count when count >= 0 ->
        {:ok, count}

      _ ->
        :ets.update_counter(opts.table_name, key, 1, {key, 0})
        {:error, :rate_limited}
    end
  end

  def get_tokens(key, opts) do
    case :ets.lookup(opts.table_name, key) do
      [{^key, count}] -> count
      [] -> opts.tokens
    end
  end

  def reset(state) do
    :ets.delete_all_objects(state.table_name)
  end
end
