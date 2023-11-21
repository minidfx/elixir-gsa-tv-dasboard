defmodule ElixirGsaTvDashboardWeb.PageController do
  use ElixirGsaTvDashboardWeb, :controller

  def index(conn, _params),
    do:
      conn
      |> put_resp_header("content-type", "text/html; charset=utf-8")
      |> send_file(200, Application.app_dir(:elixir_gsa_tv_dashboard, "priv/static/index.html"))

  def not_found(conn, _params),
    do:
      conn
      |> put_resp_header("content-type", "text/html; charset=utf-8")
      |> send_file(404, Application.app_dir(:elixir_gsa_tv_dashboard, "priv/static/not-found.html"))
end
