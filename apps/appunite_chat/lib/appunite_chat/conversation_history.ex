defmodule AppuniteChat.ConversationHistory do
  @moduledoc """
  Module that tracks the conversation history based on session id.
  """

  use GenServer

  defmodule Message do
    use TypedStruct

    typedstruct do
      field(:body, String.t(), default: "")
      field(:originator, atom, default: :user)
      field(:timestamp, DateTime.t())
    end

    @doc """
    Create a new message.

    ## Parameters
    - `body`: The message body
    - `originator`: The originator of the message (:user or :llm)

    ## Returns
    - `%__MODULE__{}`: The new message

    ## Example:
    iex> alias AppuniteChat.ConversationHistory.Message
    iex> message = Message.new("Hello, how are you?", :llm)
    iex> message.body
    "Hello, how are you?"
    iex> message.originator
    :llm
    iex> is_struct(message.timestamp, DateTime)
    true
    """
    def new(body, originator),
      do: %__MODULE__{body: body, originator: originator, timestamp: DateTime.utc_now()}
  end

  @doc """
  Start the conversation history.

  ## Parameters
  - `opts`: A map of options (not used)

  ## Returns
  - `{:ok, pid}` if the server is started successfully
  - `{:error, reason}` if the server fails to start
  """
  def start_link(opts \\ %{}), do: GenServer.start_link(__MODULE__, opts, name: __MODULE__)

  def init(opts) do
    :ets.new(__MODULE__, [:bag, :private, :named_table])
    {:ok, opts}
  end

  def handle_call({:add_message, session_id, %Message{} = message}, _from, state) do
    :ets.insert(__MODULE__, {session_id, message})
    {:reply, :ok, state}
  end

  def handle_call({:get_history, session_id}, _from, state),
    do: {:reply, :ets.lookup(__MODULE__, session_id), state}

  @doc """
  Add a message to the conversation history.

  ## Parameters
  - `session_id`: The session id to add the message to
  - `message`: The message to add

  ## Returns
  - `:ok` if the message is added successfully

  ## Example:
  iex> alias AppuniteChat.ConversationHistory
  iex> alias AppuniteChat.ConversationHistory.Message
  iex> session_id = System.unique_integer([:positive]) |> Integer.to_string()
  iex> ConversationHistory.add_message(session_id, %Message{body: "Hello, how are you?", originator: :user})
  :ok
  """
  def add_message(session_id, %Message{} = message) when is_binary(session_id),
    do: GenServer.call(__MODULE__, {:add_message, session_id, message})

  @doc """
  Get the conversation history.

  ## Parameters
  - `session_id`: The session id to get the history for

  ## Returns
  - `[Message.t()]`: The conversation history

  ## Example:
  iex> alias AppuniteChat.ConversationHistory
  iex> alias AppuniteChat.ConversationHistory.Message
  iex> session_id = System.unique_integer([:positive]) |> Integer.to_string()
  iex> ConversationHistory.add_message(session_id, %Message{body: "Hello, how are you?", originator: :user})
  iex> ConversationHistory.get_history(session_id)
  [%AppuniteChat.ConversationHistory.Message{body: "Hello, how are you?", originator: :user}]
  """
  def get_history(session_id, opts \\ []) when is_binary(session_id) do
    limit = Keyword.get(opts, :limit, 0)

    if limit > 0 do
      __MODULE__
      |> GenServer.call({:get_history, session_id})
      |> Enum.take(limit)
    else
      __MODULE__
      |> GenServer.call({:get_history, session_id})
    end
    |> format_response()
  end

  @spec get_history_as_string(binary()) :: binary()
  @doc """
  Get the conversation history as a string.

  ## Parameters
  - `session_id`: The session id to get the history for

  ## Returns
  - `String.t()`: The conversation history as a string

  ## Example:
  iex> alias AppuniteChat.ConversationHistory
  iex> alias AppuniteChat.ConversationHistory.Message
  iex> session_id = System.unique_integer([:positive]) |> Integer.to_string()
  iex> ConversationHistory.add_message(session_id, %Message{body: "Hello, how are you?", originator: :user})
  iex> ConversationHistory.get_history_as_string(session_id)
  "<user>\nHello, how are you?\n</user>"
  """
  def get_history_as_string(session_id) when is_binary(session_id) do
    session_id
    |> get_history(limit: 10)
    |> Enum.map(&format_message/1)
    |> Enum.join("\n")
  end

  # Private functions

  defp format_response(history), do: Enum.map(history, fn {_session_id, message} -> message end)

  defp format_message(message) do
    tag = if message.originator == :user, do: "user", else: "llm"
    "<#{tag}>\n" <> message.body <> "\n</#{tag}>"
  end
end
