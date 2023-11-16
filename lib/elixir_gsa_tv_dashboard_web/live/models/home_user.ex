defmodule ElixirGsaTvDashboardWeb.Models.HomeUser do
  @enforce_keys [:name]
  defstruct [:name]
  @type t :: %__MODULE__{name: String.t()}
end
