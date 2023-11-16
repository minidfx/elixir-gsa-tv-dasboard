defmodule ElixirGsaTvDashboardWeb.Models.Event do
  @enforce_keys [:title, :user, :duration, :offset]
  defstruct [:title, :user, :duration, :offset]
  @type t :: %__MODULE__{title: String.t(), user: String.t(), duration: integer(), offset: integer()}
end
