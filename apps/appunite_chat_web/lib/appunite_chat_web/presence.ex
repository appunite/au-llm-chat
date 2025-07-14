defmodule AppuniteChatWeb.Presence do
  use Phoenix.Presence,
    otp_app: :appunite_chat,
    pubsub_server: AppuniteChat.PubSub
end
