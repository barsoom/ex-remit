defmodule RemitWeb.LiveViewHelpers do
  @moduledoc false
  alias Remit.Commit
  alias RemitWeb.Router.Helpers, as: Routes
  import Phoenix.HTML.Link
  import Phoenix.HTML.Tag

  @small_commit_px 25

  def github_login(session)
  def github_login(%{"github_user" => user}), do: user.login
  def github_login(_), do: nil

  def github_avatar_sized_spacer(:small_commit) do
    content_tag(:div, "", style: "width: #{@small_commit_px}px")
  end

  def github_avatar(_, _, opts \\ [])

  def github_avatar(nil, _, _), do: nil
  def github_avatar(username, :comment, opts), do: github_avatar(username, 20, opts)
  def github_avatar(username, :small_commit, opts), do: github_avatar(username, @small_commit_px, opts)

  # Sometimes Dependabot is named "dependabot-preview", but has no avatar by that name.
  def github_avatar("dependabot-preview", size, opts), do: github_avatar("dependabot", size, opts)

  def github_avatar(username, size, opts) do
    username = Commit.botless_username(username)

    extra_classes = Keyword.get(opts, :class, "")
    tooltip = Keyword.get(opts, :tooltip, username)

    title_attr = if tooltip, do: [title: tooltip], else: []

    # Setting CSS dimensions because the `size` param is not always respected.
    content_tag(:span, title_attr ++ [class: String.trim("block #{extra_classes}")]) do
      img_tag(
        "https://github.com/#{username}.png?size=#{size}",
        alt: "",
        class: "rounded-full bg-gray-mid",
        style: "height: #{size}px; width: #{size}px;"
      )
    end
  end

  def tooltip_attributes(nil), do: []

  def tooltip_attributes(text, opts \\ []) do
    # http://kazzkiq.github.io/balloon.css/
    pos = Keyword.get(opts, :pos, "up")

    [
      "data-balloon-pos": pos,
      # No animation delay.
      "data-balloon-blunt": "",
      "aria-label": text
    ]
  end

  def filter_link(socket, assigns, component, id, text, [{param, value}]) do
    link(text,
      id: id,
      to: Routes.tabs_path(socket, component),
      class: link_classes(value, assigns[param]),
      "phx-click": "set_filter",
      "phx-value-#{param}": value,
      "phx-hook": "FilterLink",
      "data-filter-scope": component,
      "data-filter-param": param,
      "data-filter-value": value
    )
  end

  def ok(socket), do: {:ok, socket}
  def noreply(socket), do: {:noreply, socket}

  def get_filter(session, scope, param, default) do
    case Map.get(session, "filter") do
      %{^scope => %{^param => value}} -> value
      _ -> default
    end
  end

  @default_reviewed_commit_cutoff %{
    "days" => Application.compile_env(:remit, :reviewed_commit_cutoff_days),
    "commits" => Application.compile_env(:remit, :reviewed_commit_cutoff_commits),
    "days_enabled" => true,
    "commits_enabled" => true
  }

  def default_reviewed_commit_cutoff, do: @default_reviewed_commit_cutoff

  def get_reviewed_commit_cutoff(session, default \\ @default_reviewed_commit_cutoff) do
    stored = Map.get(session, "reviewed_commit_cutoff", %{})

    default
    |> Map.merge(stored)
    |> backfill_enabled(stored, "days")
    |> backfill_enabled(stored, "commits")
    |> normalize_cutoff("days")
    |> normalize_cutoff("commits")
  end

  @doc """
  Keeps "switched on" and "actually applies" from ever disagreeing.

  A cutoff that is off, 0 or blank is stored as off with its default number restored, so switching
  it back on always gives a working cutoff rather than a silently inactive one.
  """
  def normalize_cutoff(cutoff, key) do
    if Map.get(cutoff, "#{key}_enabled", true) and is_integer(cutoff[key]) and cutoff[key] > 0 do
      cutoff
    else
      cutoff
      |> Map.put(key, @default_reviewed_commit_cutoff[key])
      |> Map.put("#{key}_enabled", false)
    end
  end

  # Before the checkboxes, 0 was how you switched a cutoff off. Sessions saved back then have no
  # flag, so derive it from the number — otherwise a stored 0 would render as ticked-but-inactive.
  defp backfill_enabled(cutoff, stored, key) do
    flag = "#{key}_enabled"

    if Map.has_key?(stored, flag) do
      cutoff
    else
      Map.put(cutoff, flag, is_integer(cutoff[key]) and cutoff[key] > 0)
    end
  end

  @doc "Whether a cutoff applies: it must be switched on and be a positive number."
  def cutoff_enabled?(cutoff, key) do
    Map.get(cutoff, "#{key}_enabled", true) and is_integer(cutoff[key]) and cutoff[key] > 0
  end

  @feature_defaults %{
    "compact_design" => false,
    "advanced_filters" => false,
    "build_commit_status" => false,
    "dark_theme" => false,
    "inbox_count_badge" => false
  }

  def get_feature_flags(session) do
    Map.merge(@feature_defaults, Map.get(session, "feature_flags", %{}))
  end

  defp link_classes(link_attr, current_attr) do
    if link_attr == current_attr do
      ~w(cursor-default no-underline font-bold)
    else
      ~w(cursor-pointer underline)
    end
  end
end
