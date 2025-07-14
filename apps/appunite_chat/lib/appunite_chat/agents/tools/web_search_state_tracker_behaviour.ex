defmodule AppuniteChat.Agents.Tools.WebSearchStateTrackerBehaviour do
  @moduledoc """
  Behaviour for WebSearchStateTracker to enable mocking in tests.
  """

  @callback publish(atom(), term()) :: :ok
  @callback subscribe() :: :ok
end
