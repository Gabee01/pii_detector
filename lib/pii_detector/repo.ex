defmodule PiiDetector.Repo do
  use Ecto.Repo,
    otp_app: :pii_detector,
    adapter: Ecto.Adapters.Postgres
end
