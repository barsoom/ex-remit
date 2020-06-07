defmodule RemitWeb.CommitComponent do
  use RemitWeb, :live_component
  alias Remit.{Commit, Utils}

  defp gravatar(email, class) do
    img_tag(Gravatar.url(email), alt: "", title: email, class: class)
  end

  defp usernames(%Commit{usernames: names}) do
    names
    |> Enum.map(& content_tag(:b, &1))
    |> Enum.intersperse(" and ")
  end
end
