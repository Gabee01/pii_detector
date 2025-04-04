defmodule PiiDetectorWeb.API.WebhookController do
  use PiiDetectorWeb, :controller

  def slack(conn, _params) do
    # Will implement in next task
    conn
    |> put_status(200)
    |> json(%{status: "ok"})
  end

  def notion(conn, _params) do
    # Will implement later
    conn
    |> put_status(200)
    |> json(%{status: "ok"})
  end
end
