defmodule Reverb.Repo do
  use Ecto.Repo,
    otp_app: :reverb,
    adapter: Ecto.Adapters.Postgres
end
