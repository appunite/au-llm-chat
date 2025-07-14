defmodule AppuniteChatWeb.Application do
  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [
      AppuniteChatWeb.Presence,
      AppuniteChatWeb.Telemetry,
      {AppuniteChatWeb.MetricsStorage, AppuniteChatWeb.Telemetry.metrics()},
      AppuniteChatWeb.Endpoint
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: AppuniteChatWeb.Supervisor]
    Supervisor.start_link(children, opts)
  end

  # Tell Phoenix to update the endpoint configuration
  # whenever the application is updated.
  @impl true
  def config_change(changed, _new, removed) do
    AppuniteChatWeb.Endpoint.config_change(changed, removed)
    :ok
  end
end
