defmodule RemitWeb.CommentComponent do
  use RemitWeb, :live_component
  alias Remit.Utils

  @github_avatar_size 20

  defp github_avatar(username) do
    # Setting CSS height because the `size` param is not always respected.
    # Not setting CSS width because if the image is missing and we show the alt text, it should use more width.
    # line-height so the alt text lines up.
    size = @github_avatar_size
    img_tag("https://github.com/#{username}.png?size=#{size}", alt: username, title: username, class: "rounded-sm font-bold truncate", style: "height: #{size}px; min-width: #{size}px; line-height: #{size}px")
  end
end
