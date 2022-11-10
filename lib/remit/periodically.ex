defmodule Remit.Periodically do
  @moduledoc """
  Runs background tasks… periodically.
  """

  use GenServer

  # 1 hour
  @default_commit_cleanup_frequency_ms 60 * 60 * 1000

  @default_auth_token_cleanup_frequency_ms 10 * 60 * 1000

  # The options are for testability.
  def start_link(opts \\ []) do
    frequency_ms = Keyword.get(opts, :frequency_ms, @default_frequency_ms)

    days_string = Keyword.get(opts, :days_string, System.get_env("REMOVE_DATA_OLDER_THAN_DAYS"))
    days = days_string && String.to_integer(days_string)

    GenServer.start_link(
      __MODULE__,
      [
        remove_commits: [frequency_ms: frequency_ms, days: days],
        remove_auth_tokens: [frequency_ms: @default_auth_token_cleanup_frequency_ms],
      ],
      name: __MODULE__
    )
  end

  def init(opts) do
    commit_opts = Keyword.fetch!(opts, :remove_commits)
    ms = Keyword.fetch!(commit_opts, :frequency_ms)
    days = Keyword.fetch!(commit_opts, :days)
    if days, do: :timer.send_interval(ms, self(), {:remove_commits, days})

    auth_token_opts = Keyword.fetch!(opts, :remove_auth_tokens)
    ms = Keyword.fetch!(auth_token_opts, :frequency_ms)
    :timer.send_interval(ms, self(), :remove_tokens)

    {:ok, :no_state}
  end

  def handle_info({:remove_commits, days}, state) do
    remove_old_data(days)
    {:noreply, state}
  end

  def handle_info(:remove_tokens, state) do
    Remit.GithubAuth.delete_old_tokens()
    {:noreply, state}
  end

  defp remove_old_data(days) when is_integer(days) do
    # Deleting commits will remove all other records, via associations.
    Remit.Commits.delete_reviewed_older_than_days(days)
  end
end
