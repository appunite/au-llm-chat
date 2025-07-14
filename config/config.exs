# This file is responsible for configuring your umbrella
# and **all applications** and their dependencies with the
# help of the Config module.
#
# Note that all applications in your umbrella share the
# same configuration and dependencies, which is why they
# all use the same configuration file. If you want different
# configurations or dependencies per app, it is best to
# move said applications out of the umbrella.
import Config

config :appunite_chat_web,
  generators: [context_app: :appunite_chat]

# Configures the endpoint
config :appunite_chat_web, AppuniteChatWeb.Endpoint,
  url: [host: "localhost"],
  adapter: Bandit.PhoenixAdapter,
  render_errors: [
    formats: [html: AppuniteChatWeb.ErrorHTML, json: AppuniteChatWeb.ErrorJSON],
    layout: false
  ],
  pubsub_server: AppuniteChat.PubSub,
  live_view: [signing_salt: "ZDpxbBuQ"]

# Configure esbuild (the version is required)
config :esbuild,
  version: "0.17.11",
  appunite_chat_web: [
    args:
      ~w(js/app.js --bundle --target=es2022 --outdir=../priv/static/assets/js --external:/fonts/* --external:/images/*),
    cd: Path.expand("../apps/appunite_chat_web/assets", __DIR__),
    env: %{"NODE_PATH" => Path.expand("../deps", __DIR__)}
  ]

# Configure tailwind (the version is required)
config :tailwind,
  version: "4.0.9",
  appunite_chat_web: [
    args: ~w(
      --input=assets/css/app.css
      --output=priv/static/assets/css/app.css
    ),
    cd: Path.expand("../apps/appunite_chat_web", __DIR__)
  ]

# Configures Elixir's Logger
config :logger, :default_formatter,
  format: "$time $metadata[$level] $message\n",
  metadata: [:request_id]

# Use Jason for JSON parsing in Phoenix
config :phoenix, :json_library, Jason

# Configures Tavily API
config :appunite_chat,
  tavily_api_url: "https://api.tavily.com/",
  tavily_api_key: System.get_env("TAVILY_API_KEY")

# Chat application configuration
config :appunite_chat_web,
  max_message_length: 200,
  llm_response_timeout: 60_000

# Import environment specific config. This must remain at the bottom
# of this file so it overrides the configuration defined above.
import_config "#{config_env()}.exs"
