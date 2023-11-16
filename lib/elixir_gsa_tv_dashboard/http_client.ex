defmodule ElixirGsaTvDashboard.HttpClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl,
       String.trim_trailing(Application.get_env(:elixir_gsa_tv_dashboard, :kdrive_bridge_host_name), "/")

  plug Tesla.Middleware.Logger, debug: false
  plug Tesla.Middleware.Headers, [{"User-Agent", "tv-dashboard"}]

  plug Tesla.Middleware.BasicAuth,
    username: Application.get_env(:elixir_gsa_tv_dashboard, :basic_auth_username),
    password: Application.get_env(:elixir_gsa_tv_dashboard, :basic_auth_password)

  plug Tesla.Middleware.FollowRedirects, max_redirects: 1

  def get_planning!(), do: get!("/files/#{Application.get_env(:elixir_gsa_tv_dashboard, :planning_document_id)}")
  def get_annotation_1!(), do: get!("/files/#{Application.get_env(:elixir_gsa_tv_dashboard, :annotation_left_document_id)}")
  def get_annotation_2!(), do: get!("/files/#{Application.get_env(:elixir_gsa_tv_dashboard, :annotation_right_document_id)}")
end
