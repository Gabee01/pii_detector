defmodule PiiDetectorWeb.Router do
  use PiiDetectorWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {PiiDetectorWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", PiiDetectorWeb do
    pipe_through :browser

    get "/", PageController, :home
  end

  # API routes for webhooks
  scope "/api", PiiDetectorWeb.API do
    pipe_through :api

    post "/webhooks/slack", WebhookController, :slack
    post "/webhooks/notion", WebhookController, :notion
  end
end
