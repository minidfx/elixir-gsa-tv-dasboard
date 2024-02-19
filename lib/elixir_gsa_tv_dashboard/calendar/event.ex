defmodule ElixirGsaTvDashboard.Calendar.Event do
  @enforce_keys [:title, :user, :user_normalized, :day, :duration, :offset]
  defstruct [:title, :user, :user_normalized, :day, :duration, :offset]

  @type t :: %__MODULE__{
          title: String.t(),
          user: String.t(),
          user_normalized: String.t(),
          day: non_neg_integer(),
          duration: non_neg_integer(),
          offset: non_neg_integer()
        }
end
