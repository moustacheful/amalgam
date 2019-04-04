defmodule Log do
  @enabled System.get_env("ENABLE_LOGS")

  def info(string) do
    if @enabled, do: IO.puts(string)
  end
end
