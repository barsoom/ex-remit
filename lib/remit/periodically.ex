defmodule Remit.Periodically do
  @moduledoc """
  Runs background tasks… periodically.
  """

  use GenServer

  # 1 hour
  @default_frequency_ms 60 * 60 * 1000

  # The options are for testability.
  def start_link(opts \\ []) do
    frequency_ms = Keyword.get(opts, :frequency_ms, @default_frequency_ms)

    days_string = Keyword.get(opts, :days_string, System.get_env("REMOVE_DATA_OLDER_THAN_DAYS"))
    days = days_string && String.to_integer(days_string)

    GenServer.start_link(__MODULE__, frequency_ms: frequency_ms, days: days)
  end

  def init(opts) do
    ms = Keyword.fetch!(opts, :frequency_ms)
    days = Keyword.fetch!(opts, :days)
    if days, do: :timer.send_interval(ms, self(), {:run, days})
    {:ok, :no_state}
  end

  def handle_info({:run, days}, state) do
    remove_old_data(days)
    {:noreply, state}
  end

  defp remove_old_data(days) when is_integer(days) do
    # Deleting commits will remove all other records, via associations.
    Remit.Commits.delete_reviewed_older_than_days(days)
  end
end
