defmodule ElixirGsaTvDashboard.SunsetSunriseMonitoring.Response do
  alias ElixirGsaTvDashboard.SunsetSunriseMonitoring.Response

  @enforce_keys [:sunrise, :sunset]
  defstruct [:sunrise, :sunset]

  @type t :: %__MODULE__{
          sunrise: DateTime.t(),
          sunset: DateTime.t()
        }

  @spec from_json!(map()) :: ElixirGsaTvDashboard.SunsetSunriseMonitoring.Response.t()
  def from_json!(results) do
    {:ok, response} = from_json(results)
    response
  end

  @spec from_json(map()) :: {:ok, ElixirGsaTvDashboard.SunsetSunriseMonitoring.Response.t()} | {:error, String.t()}
  def from_json(%{"results" => %{"sunset" => sunset, "sunrise" => sunrise}}) do
    with {:ok, %DateTime{} = sunset} <- Timex.parse(sunset, "{ISO:Extended:Z}"),
         {:ok, %DateTime{} = sunrise} <- Timex.parse(sunrise, "{ISO:Extended:Z}") do
      {:ok, %Response{sunset: sunset, sunrise: sunrise}}
    else
      _ -> {:error, "Was not able to parse the response."}
    end
  end

  def from_json(results) when is_map(results),
    do: {:error, "Didn't find the properties sunset and sunrise."}
end
