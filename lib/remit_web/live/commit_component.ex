defmodule RemitWeb.CommitComponent do
  use RemitWeb, :live_component
  alias Remit.{Commit, Utils}

  defp gravatar(email, class) do
    img_tag(Gravatar.url(email), alt: "", title: email, class: class)
  end

  defp author_names(%Commit{author_usernames: usernames, author_name: name}) do
    content_tag(:span, title: name) do
      usernames
      |> Enum.map(& content_tag(:b, &1))
      |> Enum.intersperse(" and ")
    end
  end
end
