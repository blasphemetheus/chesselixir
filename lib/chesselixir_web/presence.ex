defmodule ChesselixirWeb.Presence do
  use Phoenix.Presence, otp_app: :chesselixir, pubsub_server: Chesselixir.PubSub
end
