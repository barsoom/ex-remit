defmodule RemitWeb.CommitComponent do
  use Phoenix.LiveComponent

  alias Remit.{Commit, Utils}

  defp gravatar(email, class) do
    Phoenix.HTML.Tag.img_tag(Gravatar.url(email), alt: "", title: email, class: class)
  end
end
