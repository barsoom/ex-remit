defmodule RemitWeb.UserController do
  use RemitWeb, :controller

  plug :accepts, ["json"]

  @spec set_filter_preference(Plug.Conn.t(), any) :: Plug.Conn.t()
  def set_filter_preference(conn, %{"scope" => scope, "param" => param, "value" => value}) do
    stored_filter = get_session(conn, "filter")

    conn
    |> put_session("filter", put_filter(stored_filter, scope, param, value))
    |> json(true)
  end

  def set_reviewed_commit_cutoff(conn, %{"reviewed_commit_cutoff" => cutoff}) do
    stored_cutoff = get_session(conn, "reviewed_commit_cutoff") || %{}

    conn
    |> put_session("reviewed_commit_cutoff", put_reviewed_commit_cutoff(stored_cutoff, cutoff))
    |> json(true)
  end

  def set_feature_flag(conn, %{"feature" => feature, "enabled" => enabled}) do
    stored = get_session(conn, "feature_flags") || %{}
    enabled_bool = enabled in [true, "true", "1"]

    conn
    |> put_session("feature_flags", Map.put(stored, feature, enabled_bool))
    |> json(true)
  end

  defp put_filter(nil, scope, param, value), do: put_filter(%{}, scope, param, value)

  defp put_filter(filters, scope, param, value) do
    put_in(filters, Enum.map([scope, param], &Access.key(&1, %{})), value)
  end

  defp put_reviewed_commit_cutoff(cutoff, new_cutoff) do
    new_cutoff
    |> Enum.reduce(cutoff, fn {key, value}, acc ->
      put_reviewed_commit_cutoff(acc, key, value)
    end)
  end

  defp put_reviewed_commit_cutoff(cutoff, key, value) when key in ~w[days commits] do
    number =
      case Integer.parse(String.trim(to_string(value))) do
        {number, _} -> number
        # blank, or not a number at all
        :error -> 0
      end

    cutoff
    |> Map.put(key, number)
    |> Map.put("#{key}_enabled", true)
    # 0 or blank switches the cutoff off, rather than storing a number that reads as on but isn't.
    |> RemitWeb.LiveViewHelpers.normalize_cutoff(key)
  end

  defp put_reviewed_commit_cutoff(cutoff, key, value) when key in ~w[days_enabled commits_enabled] do
    cutoff
    |> Map.put(key, value in [true, "true", "on", "1"])
    # Switching off restores the default number, so switching back on gives a working cutoff.
    |> RemitWeb.LiveViewHelpers.normalize_cutoff(String.replace_suffix(key, "_enabled", ""))
  end

  defp put_reviewed_commit_cutoff(cutoff, _key, _value), do: cutoff
end
