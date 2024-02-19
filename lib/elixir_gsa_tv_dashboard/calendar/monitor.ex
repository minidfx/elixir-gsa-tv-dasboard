defmodule ElixirGsaTvDashboard.Calendar.Monitor do
  use GenServer

  require Logger

  alias ElixirGsaTvDashboard.Calendar.User
  alias ElixirGsaTvDashboard.Calendar.Optimizer
  alias ElixirGsaTvDashboard.Calendar.Calendar
  alias ElixirGsaTvDashboard.Calendar.Event
  alias ElixirGsaTvDashboardWeb.HomeLive
  alias ElixirGsaTvDashboard.KsuiteMiddlewareHttpClient
  alias Phoenix.PubSub

  @datetime_pattern "{ISO:Extended:Z}"

  @spec start_link(any()) :: {:ok, pid()}
  def start_link(_) do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: :calendar_monitor)
    _ = Process.send_after(:calendar_monitor, :start, 1)
    {:ok, pid}
  end

  @spec topic() :: String.t()
  def topic(), do: "calendar_monitor"

  @spec get_week_interval() :: Timex.Interval.t()
  def get_week_interval(),
    do:
      Application.get_env(:elixir_gsa_tv_dashboard, :timezone)
      |> get_week_interval()

  @spec get_week_interval(String.t()) :: Timex.Interval.t()
  def get_week_interval(timezone) do
    now = Timex.now(timezone)

    beginning_of_week =
      if Timex.weekday(now) > 5,
        do: now |> Timex.shift(days: 2) |> Timex.beginning_of_week(:mon),
        else: now |> Timex.beginning_of_week(:mon)

    end_of_week = Timex.shift(beginning_of_week, days: 5)

    # CAUTION: Datetimes passed to the interval will be convert to naive!
    Timex.Interval.new(
      from: beginning_of_week |> Timex.to_datetime(:utc),
      until: end_of_week |> Timex.to_datetime(:utc),
      step: [days: 1]
    )
  end

  @spec safe_get_interval(Timex.Interval.t(), String.t()) :: {:ok, DateTime.t(), DateTime.t()}
  def safe_get_interval(%Timex.Interval{} = interval, timezone) do
    {:ok, x, y} = safe_get_interval_utc(interval)

    %DateTime{} = start_interval_zoned = Timex.Timezone.convert(x, timezone)
    %DateTime{} = end_interval_zoned = Timex.Timezone.convert(y, timezone)

    {:ok, start_interval_zoned, end_interval_zoned}
  end

  @spec safe_get_interval(Timex.Interval.t()) :: {:ok, DateTime.t(), DateTime.t()}
  def safe_get_interval(interval),
    do: safe_get_interval(interval, Application.get_env(:elixir_gsa_tv_dashboard, :timezone))

  # Callbacks

  @impl true
  @spec init(any()) :: {:ok, %{}}
  def init(_), do: {:ok, %{}}

  @impl true
  def handle_info(:start, state) do
    Logger.info("Starting the calendar monitor ...")

    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, HomeLive.topic())

    _ = Process.send_after(:calendar_monitor, :loop, 1)

    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    Logger.info("Querying the middleware to retrieve the calendar events ...")

    timezone = Application.get_env(:elixir_gsa_tv_dashboard, :timezone)
    week_interval_utc = get_week_interval(timezone)

    calendar =
      KsuiteMiddlewareHttpClient.get_planning_events!(week_interval_utc)
      |> then(&translate_to_events(&1, timezone, week_interval_utc))
      |> then(&wrap_into_calendar(&1, week_interval_utc))
      |> then(&publish_calendar/1)

    _ = Process.send_after(:calendar_monitor, :loop, get_pooling_interval())

    case calendar do
      {:ok, x} -> {:noreply, Map.put(state, :calendar, x)}
      _ -> {:noreply, state}
    end
  end

  def handle_info(%{status: "mounted", name: live_view_name}, %{calendar: %Calendar{} = calendar} = state) do
    Logger.debug("Will send the tasks by user and annotations to the view mounted: #{live_view_name}")

    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", calendar: calendar})

    {:noreply, state}
  end

  def handle_info(%{status: "mounted", name: _}, state) do
    Logger.debug("Too early, the events were not retrieved yet.")
    {:noreply, state}
  end

  # Private

  defp publish_calendar({:ok, %Calendar{} = calendar}) do
    Logger.debug("Calendar computed: #{inspect(calendar)}")
    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", calendar: calendar})
    {:ok, calendar}
  end

  defp publish_calendar({:error, reason}) do
    Logger.error(reason)
    :error
  end

  defp translate_to_events(%Tesla.Env{status: 200, body: events}, timezone, %Timex.Interval{} = week_interval)
       when is_list(events),
       do:
         {:ok,
          events
          |> Stream.map(&translate_to_event(&1, timezone, week_interval))
          |> Stream.filter(&match?({:ok, _}, &1))
          |> Stream.map(&map_event/1)}

  defp translate_to_events(%Tesla.Env{status: status}, _, _),
    do: {:error, "Received a bad response from the middleware: #{status}"}

  defp translate_to_event(event, timezone, %Timex.Interval{} = week_interval) when is_map(event) do
    with %{"description" => description, "from" => raw_from, "to" => raw_to, "subject" => subject} <- event,
         {:ok, from} <- Timex.parse(raw_from, @datetime_pattern),
         {:ok, to} <- Timex.parse(raw_to, @datetime_pattern),

         # Work with the event zoned.
         %DateTime{} = from_zoned <- Timex.Timezone.convert(from, timezone),
         %DateTime{} = to_zoned <- Timex.Timezone.convert(to, timezone),

         # Work with the interval zoned.
         {:ok, %DateTime{} = start_interval_zoned, %DateTime{} = end_interval_zoned} <-
           safe_get_interval(week_interval, timezone),

         # Extract the start/end date from the event interval.
         %Timex.Interval{} = _ <- safe_create_interval(start_interval_zoned, end_interval_zoned),

         # Make sure to have a start date inside the week interval.
         %DateTime{} = biggest_from <- datetime_max(start_interval_zoned, from_zoned),

         # Make sure to have an end date inside the week interval.
         %DateTime{} = smallest_to <- datetime_min(end_interval_zoned, to_zoned),

         # Do the dates are at midnight representing full days event.
         :ok <- is_midnight(biggest_from),
         :ok <- is_midnight(smallest_to),

         # Create a new interval inside the week interval.
         %Timex.Interval{} = duration <- safe_create_interval(biggest_from, smallest_to),

         # Does the user is present and valid in the description of the event.
         {:ok, user} <- is_valid_string(description) do
      week_day = Timex.weekday!(biggest_from)

      {:ok,
       %Event{
         title: subject,
         user: Phoenix.Naming.camelize(user),
         user_normalized: normalize_user(user),
         day: week_day,
         offset: week_day - 1,
         duration: Timex.Interval.duration(duration, :days)
       }}
    else
      {:error, :invalid_until} ->
        Logger.error("The end date of the event was invalid.")
        :skip

      :invalid ->
        Logger.error("No valid user was found in the event.")
        :skip

      :empty ->
        Logger.error("The user was not found in the event.")
        :skip

      {:error, reason} ->
        Logger.error(inspect(reason))
        :skip

      x ->
        Logger.error("An unhandled error occured, event skipped: #{inspect(x)}")
        :skip
    end
  end

  defp is_valid_string(value) when is_bitstring(value),
    do: if(String.length(value) > 0 && String.valid?(value), do: {:ok, value}, else: :empty)

  defp is_valid_string(_), do: :invalid

  defp normalize_user(user) when is_bitstring(user),
    do:
      user
      |> String.trim()
      |> String.upcase()

  defp datetime_max(%DateTime{} = x, %DateTime{} = y), do: if(Timex.compare(x, y) > 0, do: x, else: y)
  defp datetime_min(%DateTime{} = x, %DateTime{} = y), do: if(Timex.compare(x, y) < 0, do: x, else: y)

  defp is_midnight(%DateTime{hour: 0, minute: 0, second: 0}), do: :ok

  defp is_midnight(%DateTime{} = datetime),
    do: {:error, "The given datetime #{Timex.format!(datetime, @datetime_pattern)} was not a midnight."}

  defp wrap_into_calendar({:ok, stream_events}, %Timex.Interval{} = week_interval)
       when is_struct(stream_events, Stream) do
    events =
      stream_events
      |> Enum.to_list()

    users =
      events
      |> Stream.map(&map_user/1)
      |> Stream.uniq_by(fn %User{name_normalized: x} -> x end)
      |> Enum.sort()

    lines =
      events
      |> Optimizer.optimize()

    {:ok, %Calendar{lines: lines, users: users, interval: week_interval}}
  end

  defp wrap_into_calendar({:error, reason}, _),
    do: {:error, reason}

  defp map_event({:ok, %Event{} = x}), do: x

  defp map_user(%Event{user: x, user_normalized: y}),
    do: %User{name: x, name_normalized: y}

  defp get_pooling_interval(),
    do:
      Application.get_env(:elixir_gsa_tv_dashboard, :pooling_interval)
      |> safe_convert_pooling_interval()

  defp safe_convert_pooling_interval(raw) when is_bitstring(raw), do: String.to_integer(raw)
  defp safe_convert_pooling_interval(raw) when is_integer(raw), do: raw

  defp safe_create_interval(%DateTime{time_zone: tz1} = from, %DateTime{time_zone: tz2} = to) when tz1 == tz2 do
    case Timex.Interval.new(from: from, until: to) do
      {:error, reason} ->
        Logger.debug("Was not able to create an interval from the given arguments: #{from} -> #{to}", label: "new interval")
        {:error, reason}

      x ->
        x
    end
  end

  defp safe_get_interval_utc(%Timex.Interval{} = interval) do
    %Timex.Interval{from: %NaiveDateTime{} = x, until: %NaiveDateTime{} = y} = interval

    from = Timex.Timezone.convert(x, :utc)
    to = Timex.Timezone.convert(y, :utc)

    {:ok, %DateTime{} = from, %DateTime{} = to}
  end
end
