defmodule ElixirGsaTvDashboard.Calendar.Calendar do
  alias ElixirGsaTvDashboard.Calendar.User

  @enforce_keys [:users, :lines, :interval]
  defstruct [:users, :lines, :interval]
  @type t :: %__MODULE__{users: list(User), lines: list(HomeLine), interval: Timex.Interval.t()}
end
