defmodule ElixirGsaTvDashboardWeb.Models.Calendar do
  @enforce_keys [:users, :lines]
  defstruct [:users, :lines]
  @type t :: %__MODULE__{users: list(), lines: list(HomeLine)}
end
