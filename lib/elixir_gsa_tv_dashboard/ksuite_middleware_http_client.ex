defmodule ElixirGsaTvDashboard.KsuiteMiddlewareHttpClient do
  use Tesla

  plug Tesla.Middleware.BaseUrl,
       String.trim_trailing(Application.get_env(:elixir_gsa_tv_dashboard, :ksuite_middleware_server), "/")

  plug Tesla.Middleware.JSON
  plug Tesla.Middleware.Logger, debug: false
  plug Tesla.Middleware.Headers, [{"User-Agent", "tv-dashboard"}]

  plug Tesla.Middleware.BasicAuth,
    username: Application.get_env(:elixir_gsa_tv_dashboard, :basic_auth_username),
    password: Application.get_env(:elixir_gsa_tv_dashboard, :basic_auth_password)

  @spec get_planning_events!(Timex.Interval.t()) :: Tesla.Env.t()
  def get_planning_events!(interval) do
    %Timex.Interval{from: from, until: to} = interval

    get!(
      "/calendars/#{Application.get_env(:elixir_gsa_tv_dashboard, :calendar_id)}" <>
        "?from=#{Timex.format!(from, "{ISO:Extended:Z}")}" <>
        "&to=#{Timex.format!(to, "{ISO:Extended:Z}")}"
    )
  end

  @spec get_planning_csv!() :: Tesla.Env.t()
  def get_planning_csv!(), do: get!("/files/#{Application.get_env(:elixir_gsa_tv_dashboard, :planning_document_id)}")

  @spec get_annotation_1!() :: Tesla.Env.t()
  def get_annotation_1!(), do: get!("/files/#{Application.get_env(:elixir_gsa_tv_dashboard, :annotation_left_document_id)}")

  @spec get_annotation_2!() :: Tesla.Env.t()
  def get_annotation_2!(), do: get!("/files/#{Application.get_env(:elixir_gsa_tv_dashboard, :annotation_right_document_id)}")
end
