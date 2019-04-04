# Amalgam

A streaming cache proxy that avoids cache storming at all costs.

E.g.: 10 clients all request a particular url that is not in cache. The first one to come in will hit origin and start storing the headers and chunks while forwarding the data to client, the next 9 will "subscribe" to this and will receive the chunks as they come, but will never hit origin more than once.

# Why

Because reasons.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed
by adding `amalgam` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:amalgam, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc)
and published on [HexDocs](https://hexdocs.pm). Once published, the docs can
be found at [https://hexdocs.pm/amalgam](https://hexdocs.pm/amalgam).

