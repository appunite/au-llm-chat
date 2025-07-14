defmodule AppuniteChat.Agents.Tools.WebSearchStateTracker do
  @moduledoc """
  Tracks the state of the web search.
  """

  require Logger

  @behaviour AppuniteChat.Agents.Tools.WebSearchStateTrackerBehaviour

  @base_topic "web_search_state"

  @doc """
  Publish a message to the web search state tracker.

  ## Parameters
  - `type`: The type of message to publish
  - `data`: The data to publish
  - `session_id`: The session id to publish the message to

  ## Returns
  - `:ok` if the message is published successfully
  """
  def publish(type, data, session_id \\ nil) do
    topic = if session_id, do: "#{@base_topic}_#{session_id}", else: @base_topic
    Logger.info("PUBLISHED #{type} #{data} on topic #{topic} with session_id #{session_id}")
    Phoenix.PubSub.broadcast(AppuniteChat.PubSub, topic, {type, data})
  end

  @doc """
  Subscribe to the web search state tracker.

  ## Parameters
  - `session_id`: The session id to subscribe to

  ## Returns
  - `:ok` if the subscription is successful
  """
  def subscribe(session_id \\ nil) do
    topic = if session_id, do: "#{@base_topic}_#{session_id}", else: @base_topic
    Logger.info("SUBSCRIBED #{topic} with session_id #{session_id}")
    Phoenix.PubSub.subscribe(AppuniteChat.PubSub, topic)
  end
end
