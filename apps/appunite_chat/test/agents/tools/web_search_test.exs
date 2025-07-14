defmodule AppuniteChat.Agents.Tools.WebSearchTest do
  use ExUnit.Case, async: true
  import Mox

  alias AppuniteChat.Agents.Tools.WebSearch

  setup :verify_on_exit!

  describe "run/2" do
    test "successfully searches and publishes results" do
      query = "test query"
      params = %{query: query}

      mock_response = %{
        "results" => [
          %{"url" => "https://example.com/1", "title" => "Test 1"},
          %{"url" => "https://example.com/2", "title" => "Test 2"}
        ],
        "answer" => "Test answer"
      }

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, fn :query, ^query -> :ok end)
      expect(AppuniteChat.TavilyMock, :search, fn ^query, ^params -> {:ok, mock_response} end)

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, 2, fn :url, url ->
        assert url in ["https://example.com/1", "https://example.com/2"]
        :ok
      end)

      result = WebSearch.run(params, %{})
      assert {:ok, ^mock_response} = result
    end

    test "handles empty results gracefully" do
      query = "empty query"
      params = %{query: query}

      mock_response = %{"results" => []}

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, fn :query, ^query -> :ok end)
      expect(AppuniteChat.TavilyMock, :search, fn ^query, ^params -> {:ok, mock_response} end)
      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, 0, fn :url, _url -> :ok end)

      result = WebSearch.run(params, %{})
      assert {:ok, ^mock_response} = result
    end

    test "handles Tavily API errors" do
      query = "error query"
      params = %{query: query}
      error = %HTTPoison.Error{reason: :timeout}

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, fn :query, ^query -> :ok end)
      expect(AppuniteChat.TavilyMock, :search, fn ^query, ^params -> {:error, error} end)

      result = WebSearch.run(params, %{})

      assert {:error, error_message} = result
      assert error_message =~ "Error searching the web for #{query}"
      assert error_message =~ inspect(error)
    end

    test "handles malformed Tavily response" do
      query = "malformed query"
      params = %{query: query}

      malformed_response = %{"data" => "some data"}

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, fn :query, ^query -> :ok end)

      expect(AppuniteChat.TavilyMock, :search, fn ^query, ^params -> {:ok, malformed_response} end)

      result = WebSearch.run(params, %{})

      assert {:ok, _} = result
    end

    test "handles network timeout errors" do
      query = "timeout query"
      params = %{query: query}
      timeout_error = :timeout

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, fn :query, ^query -> :ok end)
      expect(AppuniteChat.TavilyMock, :search, fn ^query, ^params -> {:error, timeout_error} end)

      result = WebSearch.run(params, %{})

      assert {:error, error_message} = result
      assert error_message =~ "Error searching the web for #{query}"
      assert error_message =~ ":timeout"
    end

    test "handles results with missing URL field" do
      query = "missing url query"
      params = %{query: query}

      mock_response = %{
        "results" => [
          %{"url" => "https://example.com/valid", "title" => "Valid"},
          %{"title" => "Invalid - no URL"}
        ]
      }

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, fn :query, ^query -> :ok end)
      expect(AppuniteChat.TavilyMock, :search, fn ^query, ^params -> {:ok, mock_response} end)

      expect(AppuniteChat.WebSearchStateTrackerMock, :publish, 1, fn :url, url ->
        assert url == "https://example.com/valid"
        :ok
      end)

      result = WebSearch.run(params, %{})
      assert {:ok, ^mock_response} = result
    end
  end
end
