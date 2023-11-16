defmodule ElixirGsaTvDashboard.FilesMonitoring.BackgroundJob do
  @doc """
    This background job assumes that the external source follows the following design:

    Responsable,Lundi,Mardi,Mercredi,Jeudi,Vendredi,Samedi,Dimanche
    Paulo,Chantier1,Chantier1,Chantier2,Chantier2,Chantier2,,
    José,,Chantier1,Chantier2,Chantier2,Chantier2,Chantier3,Chantier3
  """

  use GenServer

  require Logger

  alias ElixirGsaTvDashboard.FilesMonitoring.ParserEvent
  alias ElixirGsaTvDashboard.FilesMonitoring.ParserLine
  alias ElixirGsaTvDashboard.HttpClient
  alias Phoenix.PubSub

  # Client

  def start_link(_) do
    {:ok, pid} = GenServer.start_link(__MODULE__, [], name: :files_monitoring)
    _ = Process.send_after(:files_monitoring, :start, 1_000)
    {:ok, pid}
  end

  def topic(), do: "files_monitoring"

  # Server (callbacks)

  @impl true
  def init(_) do
    {:ok, %{files: []}}
  end

  @impl true
  def handle_info(:start, state) do
    Logger.info("Starting the files monitor ...")
    _ = Process.send_after(:files_monitoring, :loop, 100)
    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "started"})
    {:noreply, state}
  end

  @impl true
  def handle_info(:loop, state) do
    Logger.debug("Querying the bridge to retrieve the documents ...")

    http_queries = [
      Task.async(&get_planning!/0),
      Task.async(&get_annotation_1!/0),
      Task.async(&get_annotation_2!/0)
    ]

    [planning_result, annotation_1, annotation_2] = Task.await_many(http_queries, 10_000)

    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", tasks_by_user: planning_result})
    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", annotation1: annotation_1})
    PubSub.broadcast!(ElixirGsaTvDashboard.PubSub, topic(), %{status: "looping", annotation2: annotation_2})

    _ = Process.send_after(:files_monitoring, :loop, get_pooling_interval())

    {:noreply, state}
  end

  # Private

  defp get_pooling_interval(),
    do:
      Application.get_env(:elixir_gsa_tv_dashboard, :pooling_interval)
      |> safe_convert_pooling_interval()

  defp safe_convert_pooling_interval(raw) when is_bitstring(raw), do: String.to_integer(raw)
  defp safe_convert_pooling_interval(raw) when is_integer(raw), do: raw

  defp get_planning!(),
    do:
      HttpClient.get_planning!()
      |> then(&translate_to_events/1)

  defp get_annotation_1!(),
    do:
      HttpClient.get_annotation_1!()
      |> then(fn %Tesla.Env{body: content} -> content end)

  defp get_annotation_2!(),
    do:
      HttpClient.get_annotation_2!()
      |> then(fn %Tesla.Env{body: content} -> content end)

  defp translate_to_events(%Tesla.Env{body: body}) when is_bitstring(body),
    do:
      body
      |> translate_to_events()

  defp translate_to_events(content) when is_bitstring(content),
    do:
      content
      # HACK: because I don't use a Stream HERE, I've to create a list with a single element.
      |> then(fn x -> [x] end)
      |> CSV.decode!(field_transform: &String.trim/1)
      |> Stream.drop(1)
      |> Stream.map(&read_line/1)
      |> Stream.filter(&match?({:ok, _}, &1))
      |> Stream.map(fn {:ok, %ParserLine{} = line} -> line end)
      |> Enum.to_list()

  defp read_line([]) do
    Logger.warning("The line was empty, no events were parsed.")
    %ParserLine{}
  end

  defp read_line(["" | _]),
    do: :skip

  defp read_line([user | tail]),
    do: {:ok, read_week_days(1, %ParserLine{user: user, events_by_name: %{}}, tail)}

  defp read_week_days(_num_week_day, %ParserLine{} = line, []),
    do: line

  defp read_week_days(num_week_day, %ParserLine{events_by_name: events} = line, [task | tail]) when num_week_day <= 7,
    do:
      task
      |> then(&normalize_task/1)
      |> then(&filter_empty_task/1)
      |> then(&fetch_existing_event_with_same_name(&1, events))
      |> then(&add_or_update_line(&1, line, num_week_day))
      |> then(&parse_next_week_day(&1, tail))

  defp read_week_days(_num_week_day, %ParserLine{} = line, _), do: line

  defp normalize_task(task),
    do: {:ok, task, task |> String.normalize(:nfd) |> String.replace(~r/[^A-z0-9\s]/u, "")}

  defp filter_empty_task({:ok, task, task_normalized}),
    do: if(!String.equivalent?(task_normalized, ""), do: {:ok, task, task_normalized}, else: :empty)

  defp return_events_and_task({:ok, %ParserEvent{} = event}, task, task_normalized), do: {:ok, event, task, task_normalized}
  defp return_events_and_task(:error, task, task_normalized), do: {:not_found_event, task, task_normalized}

  defp fetch_existing_event_with_same_name(:empty, _events), do: :empty

  defp fetch_existing_event_with_same_name({:ok, task, task_normalized}, events) when is_map(events),
    do:
      Map.fetch(events, task_normalized)
      |> then(&return_events_and_task(&1, task, task_normalized))

  defp add_or_update_line(:empty, %ParserLine{user: user} = line, num_week_day) do
    Logger.warning("The day #{num_week_day} of the user #{user} was empty and ignored.")
    {:empty, line, num_week_day}
  end

  defp add_or_update_line({:not_found_event, task, task_normalized}, %ParserLine{events_by_name: events} = line, num_week_day),
    do:
      {:ok,
       %ParserLine{
         line
         | events_by_name: Map.put_new(events, task_normalized, %ParserEvent{name: task, start_date: num_week_day, count: 1})
       }, num_week_day}

  defp add_or_update_line(
         {:ok, %ParserEvent{count: count} = event, _task, task_normalized},
         %ParserLine{events_by_name: events} = line,
         num_week_day
       ),
       do:
         {:ok, %ParserLine{line | events_by_name: Map.replace(events, task_normalized, %ParserEvent{event | count: count + 1})},
          num_week_day}

  defp parse_next_week_day({:empty, line, num_week_day}, tail), do: read_week_days(num_week_day + 1, line, tail)
  defp parse_next_week_day({:ok, line, num_week_day}, tail), do: read_week_days(num_week_day + 1, line, tail)
end
