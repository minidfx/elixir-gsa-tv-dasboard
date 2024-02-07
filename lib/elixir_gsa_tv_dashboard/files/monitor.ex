defmodule ElixirGsaTvDashboard.Files.Monitor do
  @doc """
    This background job read the annoation files.
  """

  use GenServer

  require Logger

  alias ElixirGsaTvDashboardWeb.HomeLive

  alias ElixirGsaTvDashboard.KsuiteMiddlewareHttpClient

  alias Phoenix.PubSub

  # Client

  def start_link(_) do
    {:ok, pid} = GenServer.start_link(__MODULE__, nil, name: :files_monitor)
    _ = Process.send_after(:files_monitor, :start, 1)
    {:ok, pid}
  end

  def topic(), do: "files_monitor"

  # Server (callbacks)

  @impl true
  def init(_) do
    {:ok, %{}}
  end

  @impl true
  def handle_info(:start, state) do
    Logger.info("Starting the files monitor ...")

    :ok = PubSub.subscribe(ElixirGsaTvDashboard.PubSub, HomeLive.topic())

    _ = Process.send_after(:files_monitor, :loop, 1)

    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    Logger.debug("Querying the middleware to retrieve the documents ...")

    http_queries = [
      Task.async(&get_annotation_1!/0),
      Task.async(&get_annotation_2!/0)
    ]

    [annotation_1, annotation_2] = Task.await_many(http_queries, 10_000)

    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", annotation1: annotation_1})
    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", annotation2: annotation_2})

    _ = Process.send_after(:files_monitor, :loop, get_pooling_interval())

    {:noreply,
     state
     |> Map.put(:annotation1, annotation_1)
     |> Map.put(:annotation2, annotation_2)}
  end

  def handle_info(%{status: "mounted", name: live_view_name}, %{annotation1: a1, annotation2: a2} = state) do
    Logger.debug("Will send the tasks by user and annotations to the view mounted: #{live_view_name}")

    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", annotation1: a1})
    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", annotation2: a2})

    {:noreply, state}
  end

  def handle_info(%{status: "mounted", name: _}, state) do
    Logger.debug("Too early, the files were not retrieved yet.")
    {:noreply, state}
  end

  # Private

  defp get_pooling_interval(),
    do:
      Application.get_env(:elixir_gsa_tv_dashboard, :pooling_interval)
      |> safe_convert_pooling_interval()

  defp safe_convert_pooling_interval(raw) when is_bitstring(raw), do: String.to_integer(raw)
  defp safe_convert_pooling_interval(raw) when is_integer(raw), do: raw

  defp get_annotation_1!(),
    do:
      KsuiteMiddlewareHttpClient.get_annotation_1!()
      |> then(&unwrap_body/1)
      |> then(&clean_annotations/1)

  defp get_annotation_2!(),
    do:
      KsuiteMiddlewareHttpClient.get_annotation_2!()
      |> then(&unwrap_body/1)
      |> then(&clean_annotations/1)

  defp clean_annotations({:error, reason}) do
    Logger.error(reason)
    ""
  end

  defp clean_annotations({:ok, x}), do: String.trim(x)

  defp unwrap_body(%Tesla.Env{body: x, status: 200}), do: {:ok, x}
  defp unwrap_body(%Tesla.Env{body: _, status: status}), do: {:error, "Bad status returned by the API: #{status}"}
end
