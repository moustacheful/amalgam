defmodule Fetcher do
  use GenServer

  def init(args) do
    Log.info("Fetching: method=#{args.method} url=#{args.url}")
    start_time = System.system_time(:microsecond)

    make_request(args)

    {:ok,
     %{
       key: args.key,
       start_time: start_time,
       end_time: nil,
       took: 0,
       status: :downloading,
       subscribers: [],
       http_status: nil,
       headers: nil,
       content: "",
       options: args
     }}
  end

  defp dispatch(subscribers, message) do
    Enum.each(subscribers, fn subscriber ->
      Process.send(subscriber, message, [])
    end)

    subscribers
  end

  defp add_subscriber(state, pid) do
    Map.put(state, :subscribers, state.subscribers ++ [pid])
  end

  def append_content(state, chunk) do
    Map.put(state, :content, state.content <> chunk)
  end

  defp filter_headers(headers, blacklist) do
    headers
    |> Enum.map(fn {key, value} ->
      {String.downcase(key, :ascii), value}
    end)
    |> Enum.filter(fn {name, _value} ->
      !Enum.member?(blacklist, name)
    end)
  end

  def set_headers(state, headers) do
    headers = filter_headers(headers, ["content-length", "server"])

    Map.put(state, :headers, headers)
  end

  def set_status(state, :done) do
    end_time = System.system_time(:microsecond)

    Map.merge(state, %{
      status: :done,
      end_time: end_time,
      took: end_time - state.start_time
    })
  end

  def set_status(state, status) do
    Map.put(state, :status, status)
  end

  def set_http_status(state, code) do
    Map.put(state, :http_status, code)
  end

  def handle_info(%HTTPoison.AsyncHeaders{headers: headers}, state) do
    state = Fetcher.set_headers(state, headers)

    dispatch(state.subscribers, {:on_headers, state.headers, state.http_status})
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncEnd{}, state) do
    state = Fetcher.set_status(state, :done)

    Log.info(
      "Done: method=#{state.options.method} url=#{state.options.url} took=#{state.took / 1000}ms"
    )

    dispatch(state.subscribers, {:on_end})

    Process.send(self(), :schedule_ttl, [])
    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncStatus{code: code}, state) do
    state = Fetcher.set_http_status(state, code)

    {:noreply, state}
  end

  def handle_info(%HTTPoison.AsyncChunk{chunk: chunk}, state) do
    dispatch(state.subscribers, {:on_chunk, chunk})

    state = Fetcher.append_content(state, chunk)
    {:noreply, state}
  end

  def handle_info(%HTTPoison.Error{} = err, state) do
    IO.inspect("ERROR")
    IO.inspect(err)
    state = Fetcher.set_status(state, :error)

    dispatch(state.subscribers, {:on_end})

    {:stop, :normal, state}
  end

  def handle_info(:schedule_ttl, state) do
    Process.send_after(self(), :expire, 20_000)
    {:noreply, state}
  end

  def handle_info(:expire, state) do
    Log.info(
      "Expired: method=#{state.options.method} url=#{state.options.url} subscribers=#{
        Enum.count(state.subscribers)
      } took=#{state.took / 1000}ms"
    )

    {:stop, :normal, state}
  end

  defp maybe_dispatch(processes, condition, message) do
    if condition do
      dispatch(processes, message)
    else
      processes
    end
  end

  def handle_call({:subscribe, pid}, _, state) do
    state = add_subscriber(state, pid)

    [pid]
    |> maybe_dispatch(state.headers, {:on_headers, state.headers, state.http_status})
    |> maybe_dispatch(state.content != "", {:on_chunk, state.content})
    |> maybe_dispatch(state.status == :done, {:on_end})

    {:reply, state, state}
  end

  def terminate(_, state) do
    Store.remove(state.key)
  end

  defp gen_key(options) do
    Map.take(options, [:url, :method, :params, :body])
    |> Map.update!(:params, fn params ->
      Plug.Conn.Query.encode(params)
    end)
    |> Jason.encode!()
    |> Base.encode16()
  end

  defp make_request(options) do
    Map.merge(options, %{
      method: String.downcase(options.method) |> String.to_atom(),
      headers: filter_headers(options.headers, ["host", "connection"]),
      options: [stream_to: self()]
    })
    |> Map.delete(:key)
    |> (&struct(HTTPoison.Request, &1)).()
    |> HTTPoison.request()
  end

  def get(options) do
    current_process = self()

    key = gen_key(options)
    options = Map.put(options, :key, key)

    {:ok, pid} =
      Store.upsert(key, fn ->
        {:ok, pid} = GenServer.start_link(__MODULE__, options)
        pid
      end)

    GenServer.call(pid, {:subscribe, current_process})
  end
end
