defmodule ElixirGsaTvDashboard.Calendar.User do
  @enforce_keys [:name, :name_normalized]
  defstruct [:name, :name_normalized]

  @type t :: %__MODULE__{name: String.t(), name_normalized: String.t()}
end
