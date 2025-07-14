defmodule AppuniteChat.Tavily do
  @behaviour AppuniteChat.TavilyBehaviour
  @tavily_api_url Application.compile_env(
                    :appunite_chat,
                    :tavily_api_url,
                    "https://api.tavily.com/"
                  )
  @tavily_api_key Application.compile_env!(:appunite_chat, :tavily_api_key)

  use HTTPoison.Base

  def process_request_url(endpoint) do
    @tavily_api_url <> endpoint
  end

  def process_request_headers(headers \\ []) do
    [
      {"Content-Type", "application/json"},
      {"Authorization", "Bearer #{@tavily_api_key}"}
      | headers
    ]
  end

  def process_request_body(body) do
    Map.take(body, [
      :query,
      :topic,
      :search_depth,
      :chunks_per_source,
      :max_results,
      :time_range,
      :days,
      :include_answer,
      :include_raw_content,
      :include_images,
      :include_image_descriptions,
      :include_domains,
      :exclude_domains,
      :country
    ])
    |> Enum.reject(fn {_k, v} -> is_nil(v) end)
    |> Map.new()
    |> Jason.encode!()
  end

  def process_response_body(body), do: body

  def search(query, opts \\ []) do
    body = Enum.into(opts, %{query: query})

    "search"
    |> post(body)
    |> process_post_response()
  end

  # Private functions

  defp process_post_response({:ok, %{body: response_body}}) do
    case Jason.decode(response_body) do
      {:ok, decoded} -> {:ok, decoded}
      {:error, error} -> {:error, "Failed to decode Tavily response: #{inspect(error)}"}
    end
  end

  defp process_post_response({:error, error}) do
    {:error, "Tavily API request failed: #{inspect(error)}"}
  end
end
