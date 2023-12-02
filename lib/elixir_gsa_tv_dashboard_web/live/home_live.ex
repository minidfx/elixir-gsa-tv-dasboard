defmodule ElixirGsaTvDashboardWeb.HomeLive do
  alias ElixirGsaTvDashboardWeb.Models.Line
  use ElixirGsaTvDashboardWeb, :live_view

  require Logger

  alias Phoenix.PubSub

  alias ElixirGsaTvDashboard.FilesMonitoring.BackgroundJob
  alias ElixirGsaTvDashboard.Clock
  alias ElixirGsaTvDashboard.FilesMonitoring.ParserEvent
  alias ElixirGsaTvDashboard.FilesMonitoring.ParserLine
  alias ElixirGsaTvDashboard.SunsetSunriseMonitoring.SunsetSunriseMonitoring
  alias ElixirGsaTvDashboardWeb.Models.Calendar
  alias ElixirGsaTvDashboard.FilesMonitoring.Event
  alias ElixirGsaTvDashboardWeb.Models.Event
  alias ElixirGsaTvDashboardWeb.Models.Event

  alias ElixirGsaTvDashboardWeb.EventsOptimizer

  def mount(_, _, socket) do
    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, BackgroundJob.topic())
    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, Clock.topic())
    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, SunsetSunriseMonitoring.topic())

    :ok = PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "mounted", name: ElixirGsaTvDashboardWeb.HomeLive})

    {:ok,
     socket
     |> assign(:clock_ready, false)
     |> assign(:calendar_ready, false)
     |> assign(:left_annotation_ready, false)
     |> assign(:right_annotation_ready, false)
     |> assign(:page_title, "Weekly view")
     |> assign(:dark_mode, false)}
  end

  def topic(), do: "live_view"

  # Server (callbacks)

  def handle_info(%{status: "looping", tasks_by_user: tasks_by_user}, socket) do
    users =
      tasks_by_user
      |> Enum.map(&map_user/1)
      |> Enum.dedup()
      |> Enum.sort()

    lines =
      tasks_by_user
      |> Enum.map(&translate_events/1)
      |> safe_reduce()
      |> EventsOptimizer.optimize()
      |> skip_week_end_days()

    {:noreply,
     socket
     |> assign(:calendar_ready, true)
     |> assign(:calendar, %Calendar{users: users, lines: lines})}
  end

  def handle_info(%{status: "looping", now: %DateTime{} = now}, socket) do
    {:noreply,
     socket
     |> assign(:now, now)
     |> assign(:clock_ready, true)}
  end

  def handle_info(%{status: "looping", annotation2: text}, socket) do
    {:noreply,
     socket
     |> assign(:right_annotation_ready, true)
     |> assign(
       :right_annotations,
       split_lines(text)
     )}
  end

  def handle_info(%{status: "looping", annotation1: text}, socket) do
    {:noreply,
     socket
     |> assign(:left_annotation_ready, true)
     |> assign(
       :left_annotations,
       split_lines(text)
     )}
  end

  def handle_info(%{status: "looping", daylight: is_daylight}, socket) do
    {:noreply,
     socket
     |> assign(:dark_mode, !is_daylight)}
  end

  def to_color(text) when is_bitstring(text) do
    hash = :erlang.phash2(text)
    red = :erlang.band(:erlang.bsr(hash, 16), 255)
    green = :erlang.band(:erlang.bsr(hash, 8), 255)
    blue = :erlang.band(hash, 255)

    color_code =
      <<red::size(8), green::size(8), blue::size(8)>>
      |> Base.encode16()
      |> String.downcase()

    "##{color_code}"
  end

  # Private

  defp safe_reduce([]), do: []
  defp safe_reduce(events), do: Enum.reduce(events, &flatten/2)

  defp skip_week_end_days([]), do: []

  defp skip_week_end_days(lines) when is_list(lines),
    do: lines |> Enum.map(&skip_week_end_days/1)

  defp skip_week_end_days(%Line{index: i, events: events}),
    do: %Line{index: i, events: events |> Enum.filter(&skip_week_end_days/1)}

  defp skip_week_end_days(%Event{day: d}) when d > 5, do: false
  defp skip_week_end_days(%Event{} = _event), do: true

  defp map_user(%ParserLine{user: x}), do: x

  defp split_lines(""), do: []
  defp split_lines(text), do: String.split(text, "\n")

  defp flatten(events, accumulator), do: events ++ accumulator

  defp translate_events(%ParserLine{} = line),
    do:
      line
      |> then(fn %ParserLine{events_by_name: x} -> x end)
      |> then(&Map.to_list/1)
      |> Enum.map(fn {_k, v} -> v end)
      |> Enum.map(&translate_event(line, &1))

  defp translate_event(%ParserLine{} = line, %ParserEvent{} = event) do
    %ParserLine{user: user} = line
    %ParserEvent{name: title, start_date: day, count: count_days} = event
    %Event{title: title, user: user, day: day, duration: count_days, offset: day - 1}
  end
end
