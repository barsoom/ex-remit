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
    tooltip_pos = Keyword.get(opts, :tooltip_pos, "up")

    # Setting CSS dimensions because the `size` param is not always respected.
    content_tag(:span, tooltip_attributes(tooltip, pos: tooltip_pos) ++ [class: "block #{extra_classes}"]) do
      img_tag(
        "https://github.com/#{username}.png?size=#{size}",
        alt: "",
        class: "rounded-sm bg-gray-mid",
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

  def get_filter(session, scope, param, default) do
    case Map.get(session, "filter") do
      %{^scope => %{^param => value}} -> value
      _ -> default
    end
  end

  defp link_classes(link_attr, current_attr) do
    if link_attr == current_attr do
      ~w(cursor-default no-underline font-bold)
    else
      ~w(cursor-pointer underline)
    end
  end

end
