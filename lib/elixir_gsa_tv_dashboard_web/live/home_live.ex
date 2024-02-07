defmodule ElixirGsaTvDashboardWeb.HomeLive do
  use ElixirGsaTvDashboardWeb, :live_view

  require Logger

  alias Phoenix.PubSub

  alias ElixirGsaTvDashboard.Clock

  alias ElixirGsaTvDashboard.Calendar.Calendar

  alias ElixirGsaTvDashboard.Calendar.Monitor, as: CalDavMonitor
  alias ElixirGsaTvDashboard.Files.Monitor, as: FilesMonitor
  alias ElixirGsaTvDashboard.SunsetSunriseMonitoring.Monitor, as: SunsetSunriseMonitor

  def topic(), do: "live_view"

  # Server (callbacks)

  @impl true
  def mount(_, _, socket) do
    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, Clock.topic())
    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, FilesMonitor.topic())
    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, SunsetSunriseMonitor.topic())
    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, CalDavMonitor.topic())

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

  @impl true
  def terminate(_, _) do
    :ok = PubSub.unsubscribe(ElixirGsaTvDashboard.PubSub, Clock.topic())
    :ok = PubSub.unsubscribe(ElixirGsaTvDashboard.PubSub, FilesMonitor.topic())
    :ok = PubSub.unsubscribe(ElixirGsaTvDashboard.PubSub, SunsetSunriseMonitor.topic())
    :ok = PubSub.unsubscribe(ElixirGsaTvDashboard.PubSub, CalDavMonitor.topic())

    :ok
  end

  @impl true
  def handle_info(%{status: "looping", calendar: calendar}, socket) do
    %Calendar{interval: interval} = calendar
    {:ok, from, _} = CalDavMonitor.safe_get_interval(interval)

    week_num =
      Timex.format!(from, "{Wmon}")
      |> String.to_integer()
      |> then(fn x -> x + 1 end)

    {:noreply,
     socket
     |> assign(:calendar_ready, true)
     |> assign(:calendar, calendar)
     |> assign(:week_num, week_num)
     |> assign(:interval_start, from)}
  end

  @impl true
  def handle_info(%{status: "looping", now: %DateTime{} = now}, socket) do
    {:noreply,
     socket
     |> assign(:now, now)
     |> assign(:clock_ready, true)}
  end

  @impl true
  def handle_info(%{status: "looping", annotation2: text}, socket) do
    {:noreply,
     socket
     |> assign(:right_annotation_ready, true)
     |> assign(
       :right_annotations,
       split_lines(text)
     )}
  end

  @impl true
  def handle_info(%{status: "looping", annotation1: text}, socket) do
    {:noreply,
     socket
     |> assign(:left_annotation_ready, true)
     |> assign(
       :left_annotations,
       split_lines(text)
     )}
  end

  @impl true
  def handle_info(%{status: "looping", daylight: is_daylight}, socket) do
    {:noreply,
     socket
     |> assign(:dark_mode, !is_daylight)}
  end

  @impl true
  def handle_info(%{status: "looping"}, socket), do: {:noreply, socket}

  # Private

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

  defp split_lines(""), do: []
  defp split_lines(text), do: String.split(text, "\n")
end
