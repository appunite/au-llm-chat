defmodule AppuniteChat.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      {DNSCluster, query: Application.get_env(:appunite_chat, :dns_cluster_query) || :ignore},
      {Phoenix.PubSub, name: AppuniteChat.PubSub},
      AppuniteChat.ConversationHistory
      # Start a worker by calling: AppuniteChat.Worker.start_link(arg)
      # {AppuniteChat.Worker, arg}
    ]

    Supervisor.start_link(children, strategy: :one_for_one, name: AppuniteChat.Supervisor)
  end
end
