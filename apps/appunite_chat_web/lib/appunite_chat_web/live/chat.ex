defmodule AppuniteChatWeb.Live.Chat do
  use AppuniteChatWeb, :live_view

  alias AppuniteChat.ConversationHistory
  alias AppuniteChat.Agents

  @max_message_length Application.compile_env(:appunite_chat_web, :max_message_length, 200)
  @llm_response_timeout Application.compile_env(:appunite_chat_web, :llm_response_timeout, 60_000)

  @default_error_message "Sorry, I can't help with that."
  @processing_request_error "Sorry, I encountered an error processing your request. Please try again."

  defp init_agents do
    case AppuniteChat.Agents.WebQA.start_link() do
      {:ok, web_qa_agent_pid} ->
        case AppuniteChat.Agents.TopicDrift.start_link() do
          {:ok, topic_drift_agent_pid} ->
            %{
              web_qa_agent_pid: web_qa_agent_pid,
              topic_drift_agent_pid: topic_drift_agent_pid
            }

          {:error, _reason} ->
            # Clean up the successfully started agent
            Process.exit(web_qa_agent_pid, :shutdown)

            %{
              web_qa_agent_pid: nil,
              topic_drift_agent_pid: nil
            }
        end

      {:error, _reason} ->
        %{
          web_qa_agent_pid: nil,
          topic_drift_agent_pid: nil
        }
    end
  end

  def mount(_params, _session, socket) do
    session_id = :crypto.strong_rand_bytes(16) |> Base.encode16(case: :lower)

    if connected?(socket),
      do:
        AppuniteChatWeb.Presence.track(self(), "chat_presence", session_id, %{
          online_at: System.system_time(:second)
        })

    agents = init_agents()

    {:ok,
     assign(socket,
       current_message_buffer: "",
       messages: [],
       previous_message: "",
       waiting_for_response: false,
       current_task: nil,
       session_id: session_id,
       web_qa_agent_pid: agents.web_qa_agent_pid,
       topic_drift_agent_pid: agents.topic_drift_agent_pid
     )}
  end

  defp code_inside_div(html) do
    case Regex.scan(~r/<pre><code.*?<\/code><\/pre>/s, html) do
      [] ->
        html

      matches ->
        matches
        |> Enum.reduce(html, fn [match], acc ->
          String.replace(
            acc,
            match,
            "<div class='bg-white text-black rounded-lg p-2 my-2 border border-gray-200'>#{match}</div>"
          )
        end)
    end
  end

  def markdown(assigns) do
    text = if assigns.text == nil, do: "", else: assigns.text

    # Configure Earmark options for better HTML output
    earmark_options = %Earmark.Options{
      code_class_prefix: "language-",
      smartypants: true,
      breaks: true
    }

    markdown_html =
      String.trim(text)
      |> Earmark.as_html!(earmark_options)
      |> code_inside_div()
      |> Phoenix.HTML.raw()

    assigns = assign(assigns, :markdown, markdown_html)

    ~H"""
    <div class="prose prose-sm max-w-none">
      {@markdown}
    </div>
    """
  end

  defp message(assigns) do
    ~H"""
    <%= case @message.originator do %>
      <% :user -> %>
        <div class="flex justify-end mb-4">
          <div class="max-w-[80%] lg:max-w-[70%] bg-primary text-base-content border border-base-300 rounded-2xl rounded-bl-md px-4 py-3 shadow-md">
            <.markdown text={String.trim(@message.body)} />
          </div>
        </div>
      <% :llm -> %>
        <div class="flex justify-start mb-4">
          <div class="max-w-[80%] lg:max-w-[70%] bg-base-100 text-base-content border border-base-300 rounded-2xl rounded-bl-md px-4 py-3 shadow-md">
            <.markdown text={String.trim(@message.body)} />
          </div>
        </div>
    <% end %>
    """
  end

  defp typing_indicator(assigns) do
    ~H"""
    <div class="flex justify-start mb-4">
      <div class="max-w-[80%] lg:max-w-[70%] bg-base-200 border border-base-300 rounded-2xl rounded-bl-md px-4 py-3 shadow-sm">
        <div class="flex items-center space-x-2">
          <span class="text-sm text-base-content">Waiting for response</span>
          <div class="flex space-x-1">
            <div class="w-2 h-2 bg-primary rounded-full animate-bounce"></div>
            <div class="w-2 h-2 bg-primary rounded-full animate-bounce" style="animation-delay: 0.1s">
            </div>
            <div class="w-2 h-2 bg-primary rounded-full animate-bounce" style="animation-delay: 0.2s">
            </div>
          </div>
        </div>
      </div>
    </div>
    """
  end

  def render(assigns) do
    ~H"""
    <div class="h-screen flex flex-col bg-base-200">
      <div
        class="flex-1 overflow-y-auto px-4 pt-8 pb-40 scroll-smooth"
        phx-hook="ScrollToBottom"
        id="chat-messages"
      >
        <div class="max-w-4xl mx-auto w-full">
          <%= if Enum.empty?(@messages) do %>
            <div class="flex items-center justify-center h-full">
              <div class="text-center text-base-content/60">
                <div class="text-6xl mb-4">💬</div>
                <h3 class="text-2xl font-bold mb-2 text-base-content">Welcome to Appunite Chat</h3>
                <p>Start a conversation by typing a message below.</p>
              </div>
            </div>
          <% else %>
            <%= for message <- @messages do %>
              <.message message={message} />
            <% end %>
          <% end %>

          <%= if @waiting_for_response do %>
            <.typing_indicator />
          <% end %>
        </div>
      </div>

      <div class="fixed bottom-0 left-0 right-0 bg-base-100/80 backdrop-blur-lg border-t border-base-300/20">
        <div class="max-w-4xl mx-auto p-4">
          <form phx-submit="send_message" id="chat-form" class="relative">
            <div class="flex items-end gap-3">
              <div class="flex-1 relative">
                <input
                  type="text"
                  name="current_message_buffer"
                  value={@current_message_buffer}
                  placeholder="Type your message..."
                  class="w-full px-4 py-3 pr-16 bg-base-100 border border-base-300 rounded-2xl focus:outline-none focus:ring-2 focus:ring-primary focus:border-transparent transition-all duration-200 resize-none shadow-sm"
                  phx-keyup="message_changed"
                  phx-hook="CharacterCount"
                  id="message-input"
                  maxlength="200"
                  autofocus
                  disabled={@waiting_for_response}
                />
                <div class="absolute right-4 bottom-3 text-xs text-base-content/50">
                  {String.length(@current_message_buffer)}/200
                </div>
              </div>
              <button
                type="submit"
                disabled={@waiting_for_response or String.trim(@current_message_buffer) == ""}
                class="btn btn-primary btn-circle disabled:opacity-50 disabled:cursor-not-allowed transition-all duration-200 shadow-sm"
              >
                <svg class="w-5 h-5" fill="none" stroke="currentColor" viewBox="0 0 24 24">
                  <path
                    stroke-linecap="round"
                    stroke-linejoin="round"
                    stroke-width="2"
                    d="M12 19l9 2-9-18-9 18 9-2zm0 0v-8"
                  >
                  </path>
                </svg>
              </button>
            </div>
          </form>
        </div>
      </div>
    </div>
    """
  end

  defp valid_message?(message, waiting_for_response) do
    sanitized_message = String.trim(message)

    not waiting_for_response and
      sanitized_message != "" and
      String.length(sanitized_message) <= @max_message_length and
      String.printable?(sanitized_message)
  end

  defp sanitize_message(message) do
    message
    |> String.trim()
    |> String.replace(~r/\s+/, " ")
    |> String.slice(0, @max_message_length)
  end

  defp format_message_as(message, as \\ :user) do
    as = Atom.to_string(as)
    "<#{as}>\n" <> message <> "\n</#{as}>"
  end

  defp create_response_task(message, session_id, topic_drift_agent_pid, web_qa_agent_pid) do
    Task.async(fn ->
      try do
        start_time = System.monotonic_time()

        history_as_string =
          ConversationHistory.get_history_as_string(session_id) <> format_message_as(message)

        with {:ok, _} <- check_if_agents_are_running([topic_drift_agent_pid, web_qa_agent_pid]),
             {:ok, _} <- topic_drift_handler(topic_drift_agent_pid, history_as_string),
             {:ok, _} = tool_response <-
               tool_response_handler(web_qa_agent_pid, history_as_string, @llm_response_timeout) do
          end_time = System.monotonic_time()
          diff = end_time - start_time

          :telemetry.execute([:appunite_chat, :llm_response], %{
            duration: diff,
            agent_type: "web_qa"
          })

          tool_response
        else
          {:error, :topic_drift} ->
            {:ok, %{result: "Sorry, I can't help with that."}}
        end
      catch
        :exit, {:timeout, _} ->
          :telemetry.execute([:appunite_chat, :errors], %{total: 1}, %{type: "agent_timeout"})
          {:error, :timeout}

        :exit, reason ->
          :telemetry.execute([:appunite_chat, :errors], %{total: 1}, %{type: "agent_exit"})
          {:error, {:exit, reason}}
      end
    end)
  end

  def handle_event("message_changed", %{"value" => message}, socket),
    do: {:noreply, assign(socket, current_message_buffer: message)}

  def handle_event("send_message", %{"current_message_buffer" => message}, socket) do
    %{
      waiting_for_response: waiting,
      topic_drift_agent_pid: topic_drift_pid,
      web_qa_agent_pid: web_qa_pid,
      session_id: session_id
    } = socket.assigns

    sanitized_message = sanitize_message(message)

    if valid_message?(sanitized_message, waiting) do
      :telemetry.execute([:appunite_chat, :messages], %{sent: 1}, %{})

      ConversationHistory.add_message(
        session_id,
        ConversationHistory.Message.new(sanitized_message, :user)
      )

      task = create_response_task(sanitized_message, session_id, topic_drift_pid, web_qa_pid)

      {:noreply,
       assign(socket,
         current_task: task,
         current_message_buffer: "",
         previous_message: sanitized_message,
         messages: ConversationHistory.get_history(session_id),
         waiting_for_response: true
       )}
    else
      {:noreply, assign(socket, current_message_buffer: "")}
    end
  end

  def handle_event(_, _, socket), do: {:noreply, socket}

  # Handle task completion
  def handle_info(
        {ref, result},
        %{assigns: %{previous_message: _previous_message, session_id: session_id}} =
          socket
      )
      when socket.assigns.current_task.ref == ref do
    Process.demonitor(ref, [:flush])

    message =
      case result do
        {:ok, %{result: llm_message}} when is_binary(llm_message) ->
          :telemetry.execute([:appunite_chat, :messages], %{received: 1}, %{message: llm_message})
          String.trim(llm_message)

        {:error, :topic_drift} ->
          :telemetry.execute([:appunite_chat, :topic_drift], %{count: 1}, %{})
          @default_error_message

        _error ->
          :telemetry.execute([:appunite_chat, :errors], %{total: 1}, %{type: "invalid_response"})
          @processing_request_error
      end

    ConversationHistory.add_message(
      session_id,
      ConversationHistory.Message.new(message, :llm)
    )

    {:noreply,
     assign(socket,
       current_message_buffer: "",
       previous_message: "",
       messages: ConversationHistory.get_history(session_id),
       waiting_for_response: false,
       current_task: nil
     )}
  end

  # Handle task failure
  def handle_info({:DOWN, ref, :process, _pid, _reason}, socket)
      when not is_nil(socket.assigns.current_task) and socket.assigns.current_task.ref == ref do
    :telemetry.execute([:appunite_chat, :errors], %{total: 1}, %{type: "task_failure"})

    {:noreply,
     assign(socket,
       current_message_buffer: "",
       current_task: nil,
       waiting_for_response: false
     )}
  end

  def handle_info({:DOWN, _ref, :process, _pid, _reason}, socket), do: {:noreply, socket}
  def handle_info(_msg, socket), do: {:noreply, socket}

  # private funtions

  defp tool_response_handler(pid, history, timeout) do
    case Agents.WebQA.tool_response(pid, history, timeout: timeout) do
      {:ok, %{result: _result}} = response ->
        response

      {:error, _} ->
        {:ok, %{result: @default_error_message}}
    end
  end

  defp topic_drift_handler(pid, history) do
    case Agents.TopicDrift.boolean_response(pid, history) do
      {:ok, %{result: true}} = response ->
        response

      {:ok, %{result: false}} ->
        {:error, :topic_drift}

      {:error, _} = error ->
        error
    end
  end

  defp check_if_agents_are_running([_ | _] = pids) do
    if Enum.all?(pids, fn pid -> not is_nil(pid) end) do
      {:ok, %{result: ""}}
    else
      {:ok, %{result: @default_error_message}}
    end
  end
end
