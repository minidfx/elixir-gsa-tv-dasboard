defmodule ElixirGsaTvDashboard.Files.ParserLine do
  defstruct [:user, :events_by_name]

  @type t :: %__MODULE__{
          user: String.t(),
          events_by_name: map()
        }
end
