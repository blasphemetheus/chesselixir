defmodule Chesselixir.Repo do
  use Ecto.Repo,
    otp_app: :chesselixir,
    adapter: Ecto.Adapters.Postgres
end
