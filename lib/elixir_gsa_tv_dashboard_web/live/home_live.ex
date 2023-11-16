defmodule ElixirGsaTvDashboardWeb.HomeLive do
  use ElixirGsaTvDashboardWeb, :live_view

  require Logger

  alias Phoenix.PubSub

  alias ElixirGsaTvDashboard.FilesMonitoring.BackgroundJob
  alias ElixirGsaTvDashboard.Clock
  alias ElixirGsaTvDashboardWeb.Models.Calendar
  alias ElixirGsaTvDashboard.FilesMonitoring.Event
  alias ElixirGsaTvDashboardWeb.Models.Line
  alias ElixirGsaTvDashboardWeb.Models.Event
  alias ElixirGsaTvDashboardWeb.Models.Event
  alias ElixirGsaTvDashboard.FilesMonitoring.ParserEvent
  alias ElixirGsaTvDashboard.FilesMonitoring.ParserLine

  def mount(_, _, socket) do
    PubSub.subscribe(ElixirGsaTvDashboard.PubSub, BackgroundJob.topic())
    PubSub.subscribe(ElixirGsaTvDashboard.PubSub, Clock.topic())

    {:ok,
     socket
     |> assign(:clock_ready, false)
     |> assign(:calendar_ready, false)
     |> assign(:left_annotation_ready, false)
     |> assign(:right_annotation_ready, false)}
  end

  # Server (callbacks)

  def handle_info(%{status: "looping", tasks_by_user: tasks_by_user}, socket) do
    users =
      tasks_by_user
      |> Enum.map(fn %ParserLine{user: x} -> x end)
      |> Enum.dedup()

    lines =
      tasks_by_user
      |> translate_lines()

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
       :right_annotation,
       text
     )}
  end

  def handle_info(%{status: "looping", annotation1: text}, socket) do
    {:noreply,
     socket
     |> assign(:left_annotation_ready, true)
     |> assign(
       :left_annotation,
       text
     )}
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

  defp translate_lines([]), do: []

  defp translate_lines(lines), do: translate_lines(0, lines, [])

  defp translate_lines(_index, [], new_lines), do: new_lines

  defp translate_lines(index, [%ParserLine{} = line | tail], new_lines) do
    events = translate_events(line)
    translate_lines(index + 1, tail, [%Line{index: index, events: events} | new_lines])
  end

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
    %Event{title: title, user: user, duration: count_days, offset: day - 1}
  end
end
