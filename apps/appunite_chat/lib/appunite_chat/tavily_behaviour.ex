defmodule AppuniteChat.TavilyBehaviour do
  @moduledoc """
  Behaviour for Tavily API interactions to enable mocking in tests.
  """

  @callback search(String.t(), map()) :: {:ok, map()} | {:error, term()}
end
