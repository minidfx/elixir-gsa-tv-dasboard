defmodule ElixirGsaTvDashboard.Clock do
  use GenServer

  require Logger

  alias Phoenix.PubSub

  def start_link(_) do
    with {:ok, pid} <- GenServer.start_link(__MODULE__, [], name: :clock) do
      _ = Process.send_after(:clock, :start, 1)
      {:ok, pid}
    end
  end

  def topic(), do: "clock"

  # Server (callbacks)

  @impl true
  def init(_) do
    {:ok, []}
  end

  @impl true
  def handle_info(:start, state) do
    Logger.info("Starting the clock ...")
    _ = Process.send_after(:clock, :loop, 1_000)
    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    _ = Process.send_after(:clock, :loop, 1_000)
    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", now: Timex.now("Europe/Zurich")})
    {:noreply, state}
  end
end
