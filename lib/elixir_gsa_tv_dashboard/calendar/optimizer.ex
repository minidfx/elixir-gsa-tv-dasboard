defmodule ElixirGsaTvDashboard.Calendar.Optimizer do
  alias ElixirGsaTvDashboard.Calendar.Line
  alias ElixirGsaTvDashboard.Calendar.Event

  @spec optimize(list(Event.t())) :: list(Line.t())
  def optimize([]), do: []

  def optimize(events),
    do:
      events
      |> group_events_by_day()
      |> create_lines()
      |> Enum.sort_by(&sort_by_index/1)

  defp create_lines(events_by_day), do: create_lines(events_by_day, 0, [])
  defp create_lines(events_by_day, _index_line, lines) when map_size(events_by_day) <= 0, do: lines

  defp create_lines(events_by_day, index_line, lines) do
    {line, remaining_events_by_day} = create_line(events_by_day, index_line, 1, [])
    create_lines(remaining_events_by_day, index_line + 1, [line | lines])
  end

  defp create_line(events_by_day, index_line, day, events_took) when day > 7,
    do: {
      %Line{index: index_line, events: events_took |> Enum.sort_by(&sort_by_day/1)},
      events_by_day
    }

  defp create_line(events_by_day, index_line, day, events_took) do
    with {:ok, event_found} <- find_biggest_events_by_day(events_by_day, day),
         {:ok, duration} <- fit_in_week(event_found, day) do
      events_by_day
      |> Map.update!(day, &remove_first_event/1)
      |> clean_day_if_empty(day)
      |> create_line(index_line, day + duration, [event_found | events_took])
    else
      :not_found ->
        create_line(events_by_day, index_line, day + 1, events_took)

      :too_big ->
        events_by_day
        |> Map.update!(day, &remove_first_event/1)
        |> clean_day_if_empty(day)
        |> create_line(index_line, day + 1, events_took)
    end
  end

  defp find_biggest_events_by_day(events_by_day, day) do
    with {:ok, events} <- Map.fetch(events_by_day, day),
         [head | _] <- events do
      {:ok, head}
    else
      :error -> :not_found
    end
  end

  defp clean_day_if_empty(events_by_day, day) do
    with [] <- Map.fetch!(events_by_day, day) do
      Map.delete(events_by_day, day)
    else
      [_ | _] -> events_by_day
    end
  end

  defp fit_in_week(%Event{duration: x}, day), do: if(day + x <= 8, do: {:ok, x}, else: :too_big)

  defp remove_first_event([_skip | tail]), do: tail
  defp remove_first_event([]), do: []

  defp group_events_by_day(events), do: events |> Enum.reduce(Map.new(), &group_by_day/2)

  #  Group by day the events and sort them by duration descending. This module is VERY important because all the logic
  #  to pick up events assumes that the events for a single are sorted by duration DESCENDING.
  defp group_by_day(%Event{day: d} = event, accumulator) when is_map(accumulator),
    do:
      accumulator
      |> Map.update(d, [event], fn existing_events ->
        [event | existing_events] |> Enum.sort_by(&sort_by_duration/1, :desc)
      end)

  defp sort_by_duration(%Event{duration: x}), do: x

  defp sort_by_index(%Line{index: x}), do: x

  defp sort_by_day(%Event{day: x}), do: x
end
