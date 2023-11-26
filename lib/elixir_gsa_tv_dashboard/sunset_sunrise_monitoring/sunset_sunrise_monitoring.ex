defmodule ElixirGsaTvDashboard.SunsetSunriseMonitoring.SunsetSunriseMonitoring do
  use GenServer

  require Logger

  alias Timex.Timezone
  alias Timex.Duration
  alias ElixirGsaTvDashboardWeb.HomeLive
  alias ElixirGsaTvDashboard.SunsetSunriseMonitoring.Response
  alias ElixirGsaTvDashboard.SunsetSunriseMonitoring.SunsetSunriseTimeHttpClient
  alias Phoenix.PubSub

  @padding 10

  def start_link(_) do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: :sunrise_sunset_monitoring)
    _ = Process.send_after(:sunrise_sunset_monitoring, :start, 1)
    {:ok, pid}
  end

  @spec topic() :: String.t()
  def topic(), do: "sunrise_sunset_monitoring"

  # Server (callbacks)

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_info(:start, state) do
    Logger.info("Starting the sunrise/sunset monitor ...")

    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, HomeLive.topic())

    _pid = Process.send_after(:sunrise_sunset_monitoring, :loop, 1)

    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, %{sunrise: _, sunset: _} = state) do
    Logger.info("Querying the sunrise/sunset API to determine the dark mode and schedule the next call ...")

    timezone = Application.get_env(:elixir_gsa_tv_dashboard, :timezone)

    request_date =
      Timex.now(timezone)
      |> request_date(state)

    with {:ok, %Response{sunset: sunset, sunrise: sunrise}} <- SunsetSunriseTimeHttpClient.get_sunset_sunrise_time(request_date),
         %DateTime{} = sunset_zoned <- Timezone.convert(sunset, timezone),
         %DateTime{} = sunrise_zoned <- Timezone.convert(sunrise, timezone) do
      is_daylight =
        Timex.now(timezone)
        |> Timex.between?(sunrise_zoned, sunset_zoned)

      _ =
        PubSub.broadcast!(
          ElixirGsaTvDashboard.PubSub,
          topic(),
          %{
            status: "looping",
            daylight: is_daylight
          }
        )

      now = Timex.now(timezone)

      sleep =
        now
        |> next_contact(sunrise_zoned, sunset_zoned)
        |> Duration.add(Duration.from_seconds(@padding))

      Logger.info("Will sleep #{Duration.to_seconds(sleep)} seconds and I will wake up at #{Timex.add(now, sleep)} bye bye.")

      _ = Process.send_after(:sunrise_sunset_monitoring, :loop, Duration.to_milliseconds(sleep, truncate: true))

      {:noreply,
       state
       |> Map.put(:sunset, sunset_zoned)
       |> Map.put(:sunrise, sunrise_zoned)
       |> Map.put(:is_daylight, is_daylight)}
    else
      _ ->
        Logger.warning("Was not able to query the sunrise/sunset API.")
        {:noreply, state}
    end
  end

  def handle_info(:loop, state) do
    Logger.info("Querying the sunrise/sunset API the first time to retrieve daily sunset/sunrise hours ...")

    timezone = Application.get_env(:elixir_gsa_tv_dashboard, :timezone)
    now = Timex.now(timezone)
    request_date = request_date(now, state)

    with {:ok, %Response{sunset: sunset, sunrise: sunrise}} <- SunsetSunriseTimeHttpClient.get_sunset_sunrise_time(request_date),
         %DateTime{} = sunset_zoned <- Timex.Timezone.convert(sunset, timezone),
         %DateTime{} = sunrise_zoned <- Timex.Timezone.convert(sunrise, timezone) do
      _ = Process.send_after(:sunrise_sunset_monitoring, :loop, 1)

      {:noreply,
       state
       |> Map.put(:sunset, sunset_zoned)
       |> Map.put(:sunrise, sunrise_zoned)}
    else
      _ ->
        Logger.warning("Was not able to query the sunrise/sunset API the first time.")
        {:noreply, state}
    end
  end

  def handle_info(%{status: "mounted", name: live_view_name}, state) do
    Logger.debug("Will send the information about the daylight to the live view mounted: #{live_view_name}")

    _ =
      PubSub.broadcast!(
        ElixirGsaTvDashboard.PubSub,
        topic(),
        %{
          status: "looping",
          daylight: Map.get(state, :is_daylight, false)
        }
      )

    {:noreply, state}
  end

  # Private

  defp request_date(now, %{sunset: %DateTime{} = sunset}) do
    with :same <- same_day(now, sunset),
         :smaller <- smaller_than(now, sunset) do
      now
      |> Timex.to_date()
    else
      :different ->
        now
        |> Timex.to_date()

      :greater_or_equals ->
        now
        |> Timex.to_date()
        |> Timex.add(Duration.from_days(1))
    end
  end

  defp request_date(now, _state), do: now |> Timex.to_date()

  defp smaller_than(x, y), do: if(x < y, do: :smaller, else: :greater_or_equals)

  defp same_day(dt1, dt2), do: if(Timex.equal?(Timex.to_date(dt1), Timex.to_date(dt2)), do: :same, else: :different)

  defp next_contact(%DateTime{} = now, %DateTime{} = sunrise, %DateTime{} = _) when now < sunrise,
    do: Timex.diff(sunrise, now, :duration)

  defp next_contact(%DateTime{} = now, %DateTime{} = _, %DateTime{} = sunset) when now < sunset,
    do: Timex.diff(sunset, now, :duration)

  defp next_contact(%DateTime{} = now, %DateTime{} = sunrise, %DateTime{} = _),
    do: Timex.diff(sunrise, now, :duration)
end
