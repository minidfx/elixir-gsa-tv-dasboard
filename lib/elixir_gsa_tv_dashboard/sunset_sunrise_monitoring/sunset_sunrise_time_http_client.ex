defmodule ElixirGsaTvDashboard.SunsetSunriseMonitoring.SunsetSunriseTimeHttpClient do
  use Tesla

  alias ElixirGsaTvDashboard.SunsetSunriseMonitoring.Response

  plug Tesla.Middleware.BaseUrl, "https://api.sunrise-sunset.org"

  plug Tesla.Middleware.Logger, debug: true
  plug Tesla.Middleware.Headers, [{"User-Agent", "tv-dashboard"}]

  plug Tesla.Middleware.DecodeJson

  @spec get_sunset_sunrise_time(Timex.Date.t()) :: {:ok, Response.t()} | {:error, any()}
  def get_sunset_sunrise_time(date),
    do:
      get("/json",
        query: [
          lat: Application.get_env(:elixir_gsa_tv_dashboard, :sunset_latitude),
          lng: Application.get_env(:elixir_gsa_tv_dashboard, :sunset_longitude),
          date: Timex.format!(date, "{YYYY}-{0M}-{D}"),
          formatted: 0
        ]
      )
      |> then(&unwrap_body/1)
      |> then(&parse_to_response/1)

  defp unwrap_body({:error, reason}), do: {:error, reason}
  defp unwrap_body({:ok, %Tesla.Env{body: body, status: 200}}), do: {:ok, body}
  defp unwrap_body({:ok, %Tesla.Env{status: status}}), do: {:error, "Bad response from the server: #{status}."}

  defp parse_to_response({:ok, body}), do: Response.from_json(body)
  defp parse_to_response({:error, reason}), do: {:error, reason}
end
