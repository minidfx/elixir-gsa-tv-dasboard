defmodule ElixirGsaTvDashboard.Calendar.Calendar do
  @enforce_keys [:users, :lines, :interval]
  defstruct [:users, :lines, :interval]
  @type t :: %__MODULE__{users: list(), lines: list(HomeLine), interval: Timex.Interval.t()}
end
