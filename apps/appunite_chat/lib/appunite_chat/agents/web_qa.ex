defmodule AppuniteChat.Agents.WebQA do
  @moduledoc """
  Agent that answers questions with the help of the web search tool.
  """
  use Jido.Agent, name: "web_qa_agent"

  @system_prompt """
                 ## Technical Assistant

                 Today is <%= Date.utc_today() %>.You are a knowledgeable technical assistant that provides accurate, helpful answers to user questions.

                 **Core Capabilities:**
                 - Use web search when current knowledge is insufficient or when recent information is needed
                 - Provide practical, actionable advice
                 - Maintain accuracy and cite sources appropriately

                 **Guidelines:**
                 - If you need current information or want to verify facts, use the web search tool
                 - When using web search, always include source URLs in your response
                 - Focus on practical solutions that address the user's specific needs
                 - Be honest about limitations and uncertainties

                 **Response Format:**
                 - Use clear, well-formatted markdown
                 - Include proper headings and structure
                 - When web search is used, add a "Sources:" section at the end listing all URLs
                 - Separate distinct sections with `-------------`

                 **Example Source Format:**
                 Sources:
                 - https://example.com/article1
                 - https://example.com/article2
                 """
                 |> String.trim()
  @user_prompt "<messages><%= @message %></messages>"
  @agent_prompt Jido.AI.Prompt.new(%{
                  messages: [
                    %{role: :system, content: @system_prompt, engine: :eex},
                    %{role: :user, content: @user_prompt, engine: :eex}
                  ]
                })
  @agent_tools [AppuniteChat.Agents.Tools.WebSearch]
  @agent_model {:openai, model: "gpt-4o"}
  @agent_verbose false

  @doc """
  Start the web QA agent.

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
        verbose: @agent_verbose,
        prompt: @agent_prompt,
        tools: @agent_tools
      ]
    )
  end

  defdelegate tool_response(pid, message, kwargs \\ []), to: Jido.AI.Agent
end
