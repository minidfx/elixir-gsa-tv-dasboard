defmodule ElixirGsaTvDashboardWeb.Models.Event do
  @enforce_keys [:title, :user, :day, :duration, :offset]
  defstruct [:title, :user, :day, :duration, :offset]

  @type t :: %__MODULE__{
          title: String.t(),
          user: String.t(),
          day: non_neg_integer(),
          duration: non_neg_integer(),
          offset: non_neg_integer()
        }
end
