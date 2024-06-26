defmodule ElixirGsaTvDashboardWeb.Router do
  use ElixirGsaTvDashboardWeb, :router

  pipeline :browser do
    plug :accepts, ["html"]
    plug :fetch_session
    plug :fetch_live_flash
    plug :put_root_layout, html: {ElixirGsaTvDashboardWeb.Layouts, :root}
    plug :protect_from_forgery
    plug :put_secure_browser_headers
  end

  pipeline :api do
    plug :accepts, ["json"]
  end

  scope "/", ElixirGsaTvDashboardWeb do
    pipe_through :browser

    get "/", PageController, :index

    live "/6bb0a018-a3d8-4d38-be8b-e8de9afcfa95", HomeLive
  end

  # Other scopes may use custom stacks.
  # scope "/api", ElixirGsaTvDashboardWeb do
  #   pipe_through :api
  # end

  # Enable LiveDashboard in development
  if Application.compile_env(:elixir_gsa_tv_dashboard, :dev_routes) do
    # If you want to use the LiveDashboard in production, you should put
    # it behind authentication and allow only admins to access it.
    # If your application does not have an admins-only section yet,
    # you can use Plug.BasicAuth to set up some basic authentication
    # as long as you are also using SSL (which you should anyway).
    import Phoenix.LiveDashboard.Router

    scope "/dev/24c0f79a-d6ca-4e45-85f3-6e4fb0b2b716" do
      pipe_through :browser

      live_dashboard "/dashboard", metrics: ElixirGsaTvDashboardWeb.Telemetry
    end
  end

  scope "/", ElixirGsaTvDashboardWeb do
    pipe_through :browser

    get "/*path", PageController, :not_found
  end
end
