defmodule Helpers do
  def validate_url(url) do
    case URI.parse(url) do
      %URI{scheme: nil} -> {:error, "Invalid URL, no scheme given"}
      %URI{host: nil} -> {:error, "Invalid URL, no host given"}
      _ -> {:ok, url}
    end
  end

  def validate_url!(url) do
    case validate_url(url) do
      {:error, message} -> raise(message)
      {:ok, url} -> url
    end
  end

  def query_decode_multi(qs) do
    URI.query_decoder(qs)
    |> Enum.group_by(&elem(&1, 0), &elem(&1, 1))
    |> Enum.reduce([], fn {k, v}, acc ->
      acc ++
        case v do
          [val] ->
            [{k, val}]

          many ->
            Enum.reduce(many, [], fn val, sub_acc ->
              sub_acc ++ [{"#{k}[]", val}]
            end)
        end
    end)
  end
end
