defmodule AppuniteChat.Agents.Tools.WebSearch do
  @moduledoc """
  Web search tool that uses Tavily to search the web and track search state.
  """

  alias AppuniteChat.Agents.Tools.WebSearchStateTracker

  use Jido.Action,
    name: "web_search",
    description: "Search the web for information",
    category: "Web",
    tags: ["web", "search"],
    vsn: "1.0.0",
    compensation: [
      timeout: 30_000,
      max_retries: 3,
      enabled: true
    ],
    schema: [
      query: [type: :string, doc: "The query to search the web for", default: ""]
    ]

  @state_tracker_impl Application.compile_env(
                        :appunite_chat,
                        :web_search_state_tracker_impl,
                        WebSearchStateTracker
                      )
  @tavily_impl Application.compile_env(:appunite_chat, :tavily_impl, AppuniteChat.Tavily)

  @doc """
  Executes a web search using the configured Tavily implementation.

  ## Parameters
  - `params`: Map containing the search query
  - `_context`: Jido context (unused)

  ## Returns
  - `{:ok, response}` on successful search
  - `{:error, reason}` on failure
  """
  def run(params, _context) do
    start_time = System.monotonic_time()

    :telemetry.execute([:appunite_chat, :web_search], %{queries: 1}, %{})

    track_query(params.query)

    case perform_search(params) do
      {:ok, response} ->
        end_time = System.monotonic_time()
        diff = end_time - start_time

        :telemetry.execute(
          [:appunite_chat, :web_search],
          %{
            duration: diff
          },
          %{}
        )

        :telemetry.execute([:appunite_chat, :web_search], %{success: 1}, %{})

        process_search_results(response)
        {:ok, response}

      {:error, reason} ->
        :telemetry.execute([:appunite_chat, :web_search], %{errors: 1}, %{})
        :telemetry.execute([:appunite_chat, :errors], %{total: 1}, %{})

        {:error, format_error_message(params.query, reason)}
    end
  end

  # Private functions

  defp track_query(query) do
    @state_tracker_impl.publish(:query, query)
  end

  defp perform_search(params) do
    @tavily_impl.search(params.query, params)
  end

  defp process_search_results(%{"results" => results}) do
    results
    |> extract_valid_urls()
    |> track_urls()
  end

  defp process_search_results(_), do: :ok

  defp extract_valid_urls(results) do
    results
    |> Enum.filter(&Map.has_key?(&1, "url"))
    |> Enum.map(& &1["url"])
  end

  defp track_urls(urls) do
    Enum.each(urls, fn url ->
      @state_tracker_impl.publish(:url, url)
    end)
  end

  defp format_error_message(query, reason) do
    "Error searching the web for #{query}: #{inspect(reason)}"
  end
end
