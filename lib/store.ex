defmodule Store do
  def child_spec(opts \\ []) do
    %{
      id: __MODULE__,
      start: {__MODULE__, :start_link, [opts]},
      restart: :permanent,
      type: :worker
    }
  end

  def init(_args) do
    {:ok, %{}}
  end

  def handle_call({:has, key}, _from, state) do
    result = Map.has_key?(state, key)

    {:reply, result, state}
  end

  def handle_call({:remove, key}, _from, state) do
    state = Map.delete(state, key)

    {:reply, :ok, state}
    # |> IO.inspect()
  end

  def handle_call({:set, key, value}, _from, state) do
    state = Map.put(state, key, value)

    {:reply, value, state}
    # |> IO.inspect()
  end

  def handle_call({:get, url}, _from, state) do
    child_pid = Map.get(state, url)

    {:reply, child_pid, state}
    # |> IO.inspect()
  end

  def handle_call({:upsert, key, insert_function}, _from, state) do
    state = Map.put_new_lazy(state, key, insert_function)

    {:reply, {:ok, Map.get(state, key)}, state}
  end

  def start_link(_) do
    GenServer.start_link(__MODULE__, nil, name: __MODULE__)
  end

  def set(key, value) do
    GenServer.call(__MODULE__, {:set, key, value})
  end

  def has?(key) do
    GenServer.call(__MODULE__, {:has, key})
  end

  def get(key) do
    GenServer.call(__MODULE__, {:get, key})
  end

  def remove(key) do
    GenServer.call(__MODULE__, {:remove, key})
  end

  def upsert(key, insert_function) do
    GenServer.call(__MODULE__, {:upsert, key, insert_function})
  end
end
