defmodule Amalgam.Router do
  use Plug.Router
  use Plug.Debugger
  # require Logger

  # plug(Plug.Logger, log: :debug)

  plug(:match)
  plug(:dispatch)

  def stream(pid, %Plug.Conn{state: :unset} = conn) do
    conn =
      receive do
        {:on_headers, headers, status} ->
          conn
          |> Plug.Conn.merge_resp_headers(headers)
          |> Plug.Conn.send_chunked(status)
      end

    stream(pid, conn)
  end

  def stream(pid, %Plug.Conn{} = conn) do
    receive do
      {:on_chunk, content} ->
        Plug.Conn.chunk(conn, content)
        stream(pid, conn)

      {:on_end} ->
        conn
    end
  end

  get "/favicon.ico" do
    send_resp(conn, 404, 'Not found.')
  end

  match _ do
    {:ok, body, conn} = read_body(conn)

    [url, qs] =
      conn.request_path
      |> String.slice(1..-1)
      |> URI.decode()
      |> Helpers.validate_url!()
      |> String.split("?")
      |> case do
        [_url, _qs] = list -> list
        [url] -> [url, ""]
      end

    Fetcher.get(%{
      url: url,
      body: body,
      method: conn.method,
      headers: conn.req_headers,
      params: Helpers.query_decode_multi(qs)
    })
    |> stream(conn)
  end
end
