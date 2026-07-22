defmodule Sipaex.Repo do
  use Ecto.Repo,
    otp_app: :sipaex,
    adapter: Ecto.Adapters.Postgres
end
