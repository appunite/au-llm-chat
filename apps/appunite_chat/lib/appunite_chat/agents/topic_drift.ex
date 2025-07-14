defmodule AppuniteChat.Agents.TopicDrift do
  @moduledoc """
  Agent that determines if the user's message is related to the topic.
  """

  use Jido.Agent, name: "topic_drift_agent"

  @system_prompt """
                 You are a helpful assistant that determines if the user's message is related to the topic.

                 <task>
                 Based on the user's messages and the current topic, determine if the user's message is related to the overall technical topic.

                 Be aware of:
                 - Changing the topic to something unrelated to the technical topic.
                 - Requesting to generate content that is not related to the technical topic.

                 If users asks something about appunite, return "yes".
                 If the user message is welcoming, return "yes".
                 If there is no history, return "yes".
                 If the user message drifts from the technical topic, return "no".
                 Otherwise return "yes".
                 </task>
                 """
                 |> String.trim()
  @user_prompt "<messages><%= @message %></messages>"
  @agent_prompt Jido.AI.Prompt.new(%{
                  messages: [
                    %{role: :system, content: @system_prompt, engine: :eex},
                    %{role: :user, content: @user_prompt, engine: :eex}
                  ]
                })
  @agent_tools []
  @agent_model {:openai, model: "gpt-4o"}
  @agent_verbose false

  @doc """
  Start the topic drift agent.

  ## Parameters
  - `opts`: A map of options (not used)

  ## Returns
  - `{:ok, pid}` if the agent is started successfully
  - `{:error, reason}` if the agent fails to start
  """
  def start_link(_opts \\ %{}) do
    Jido.AI.Agent.start_link(
      agent: __MODULE__,
      ai: [
        model: @agent_model,
        prompt: @agent_prompt,
        verbose: @agent_verbose,
        tools: @agent_tools
      ]
    )
  end

  defdelegate boolean_response(pid, message, kwargs \\ []), to: Jido.AI.Agent
end
