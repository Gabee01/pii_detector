defmodule PIIDetectorWeb.Router do
  use PIIDetectorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PIIDetectorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PIIDetectorWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API routes for webhooks
  scope "/api", PIIDetectorWeb.API do
    pipe_through :api

    post "/webhooks/slack", WebhookController, :slack
    post "/webhooks/notion", WebhookController, :notion
  end
end
