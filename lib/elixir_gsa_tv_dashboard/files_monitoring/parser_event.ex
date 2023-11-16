defmodule ElixirGsaTvDashboard.FilesMonitoring.ParserEvent do
  defstruct [:name, :count, :start_date]

  @type t :: %__MODULE__{
          name: String.t(),
          start_date: integer(),
          count: integer()
        }
end
