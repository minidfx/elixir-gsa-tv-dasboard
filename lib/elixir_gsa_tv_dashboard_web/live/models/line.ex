defmodule ElixirGsaTvDashboardWeb.Models.Line do
  @enforce_keys [:index, :events]
  defstruct [:index, :events]
  @type t :: %__MODULE__{index: non_neg_integer(), events: list(Event)}
end
