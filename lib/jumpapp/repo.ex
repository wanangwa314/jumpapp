defmodule Jumpapp.Repo do
  use Ecto.Repo,
    otp_app: :jumpapp,
    adapter: Ecto.Adapters.SQLite3
end
