defmodule Amalgam do
  use Application

  @moduledoc """
  Documentation for Amalgam.
  """

  def start(_, _) do
    # :observer.start()
    {port, _} =
      Integer.parse(System.get_env("PORT"))
      |> IO.inspect()

    children = [
      Plug.Cowboy.child_spec(
        scheme: :http,
        plug: Amalgam.Router,
        options: [port: port]
      ),
      Store.child_spec()
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: Amalgam.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
