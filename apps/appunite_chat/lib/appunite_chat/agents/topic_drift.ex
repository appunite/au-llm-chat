defmodule AppuniteChat.Agents.TopicDrift do
  @moduledoc """
  Agent that determines if the user's message is related to the topic.
  """

  use Jido.Agent, name: "topic_drift_agent"

  @system_prompt """
                 You are a topic relevance detector that determines if a user's message stays within the current conversation scope.

                 **Task:**
                 Analyze the user's message and determine if it relates to the ongoing discussion.

                 **Return "yes" if:**
                 - The message is a greeting or welcome
                 - This is the first message in the conversation
                 - The message continues the current technical topic
                 - The message asks for clarification about previous responses
                 - The message relates to technical subjects in general

                 **Return "no" if:**
                 - The message completely changes to an unrelated, non-technical topic
                 - The message requests content generation unrelated to the technical discussion
                 - The message is clearly off-topic or inappropriate

                 **Output:** Respond with only "yes" or "no".
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
