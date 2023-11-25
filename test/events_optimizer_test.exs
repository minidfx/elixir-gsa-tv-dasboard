defmodule EventsOptimizerTest do
  use ExUnit.Case

  @moduletag timeout: 2_000

  alias ElixirGsaTvDashboardWeb.Models.Line
  alias ElixirGsaTvDashboardWeb.Models.Event
  alias ElixirGsaTvDashboard.EventsOptimizer

  defp create_event(title, day, duration, user),
    do: %Event{title: title, user: user, day: day, duration: duration, offset: day - 1}

  test "optimize with an optimize list" do
    actual = EventsOptimizer.optimize([])
    expected = []

    assert expected == actual
  end

  test "optimize with a single event" do
    actual = EventsOptimizer.optimize([%Event{title: "fake event", user: "me", day: 1, duration: 3, offset: 2}])
    expected_lines = [%Line{index: 0, events: [%Event{title: "fake event", user: "me", day: 1, duration: 3, offset: 2}]}]

    assert expected_lines == actual
  end

  test "optimize with many events less than 1 week on the same day" do
    events =
      [
        create_event("fake event", 1, 3, "user 1"),
        create_event("another fake event", 2, 3, "user 2")
      ]

    actual = EventsOptimizer.optimize(events)

    expected_lines =
      [
        %Line{index: 0, events: [create_event("fake event", 1, 3, "user 1")]},
        %Line{index: 1, events: [create_event("another fake event", 2, 3, "user 2")]}
      ]

    assert expected_lines == actual
  end

  test "optimize with many events" do
    events =
      [
        create_event("fake event 1", 1, 3, "user 1"),
        create_event("fake event 2", 4, 3, "user 1"),
        create_event("fake event 3", 6, 1, "user 1"),
        create_event("fake event 4", 1, 1, "user 2"),
        create_event("fake event 5", 2, 1, "user 2"),
        create_event("fake event 6", 3, 1, "user 2"),
        create_event("fake event 7", 7, 1, "user 3")
      ]

    actual = EventsOptimizer.optimize(events)

    expected_lines =
      [
        %Line{
          index: 0,
          events: [
            create_event("fake event 1", 1, 3, "user 1"),
            create_event("fake event 2", 4, 3, "user 1"),
            create_event("fake event 7", 7, 1, "user 3")
          ]
        },
        %Line{
          index: 1,
          events: [
            create_event("fake event 4", 1, 1, "user 2"),
            create_event("fake event 5", 2, 1, "user 2"),
            create_event("fake event 6", 3, 1, "user 2"),
            create_event("fake event 3", 6, 1, "user 1")
          ]
        }
      ]

    assert expected_lines == actual
  end
end
