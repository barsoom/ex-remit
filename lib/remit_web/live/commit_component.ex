defmodule RemitWeb.CommitComponent do
  use Phoenix.LiveComponent
  alias Remit.{Commit, Utils}

  defp gravatar(email, class) do
    Phoenix.HTML.Tag.img_tag(Gravatar.url(email), alt: "", title: email, class: class)
  end

  defp author_names(%Commit{author_usernames: usernames, author_name: name}) do
    Phoenix.HTML.Tag.content_tag(:span, title: name) do
      usernames
      |> Enum.map(& Phoenix.HTML.Tag.content_tag(:b, &1))
      |> Enum.intersperse(" and ")
    end
  end
end
