defmodule RemitWeb.LiveViewHelpers do
  alias Remit.Commit

  def github_avatar(_, _, opts \\ [])

  def github_avatar(nil, _, _), do: nil
  def github_avatar(username, :comment, opts), do: github_avatar(username, 20, opts)
  def github_avatar(username, :small_commit, opts), do: github_avatar(username, 25, opts)

  def github_avatar(username, size, opts) do
    extra_classes = Keyword.get(opts, :class, "")
    alt = Keyword.get(opts, :alt, username)

    username = Commit.botless_username(username)

    # Setting CSS height because the `size` param is not always respected.
    # Not setting CSS width because if the image is missing and we show the alt text, it should use more width.
    # line-height so the alt text lines up.
    Phoenix.HTML.Tag.img_tag(
      "https://github.com/#{username}.png?size=#{size}",
      alt: alt,
      title: username,
      class: "rounded-sm font-bold truncate #{extra_classes}",
      style: "height: #{size}px; min-width: #{size}px; line-height: #{size}px"
    )
  end

  def tooltip_attributes(text) do
    # http://kazzkiq.github.io/balloon.css/
    [
      "data-balloon-pos": "up",  # Above.
      "data-balloon-blunt": "",  # No animation delay.
      "aria-label": text,
    ]
  end
end
