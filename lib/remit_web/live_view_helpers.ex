defmodule RemitWeb.LiveViewHelpers do
  alias Remit.Commit
  import Phoenix.HTML.Tag

  @small_commit_px 25

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
end
