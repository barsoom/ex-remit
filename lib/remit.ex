defmodule Remit do
  @moduledoc """
  Remit keeps the contexts that define your domain
  and business logic.

  Contexts are also responsible for managing your data, regardless
  if it comes from the database, an external API or others.
  """

  def schema do
    quote do
      @timestamps_opts [type: :utc_datetime_usec]

      use Ecto.Schema
      import Ecto.Query
      alias __MODULE__
    end
  end

  defmacro __using__(which) when is_atom(which) do
    apply(__MODULE__, which, [])
  end
end
