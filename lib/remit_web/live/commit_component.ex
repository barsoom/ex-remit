defmodule RemitWeb.CommitComponent do
  use RemitWeb, :live_component
  alias Remit.{Commit, Utils}

  defp usernames(%Commit{usernames: []}) do
    content_tag(:span,
      title: "Read about commit usernames under the \"Settings\" tab.",
      class: "bg-gray-light rounded py-px px-1 text-gray-dark"
    ) do
      [
        content_tag(:i, "", class: "fas fa-exclamation-circle text-red-600"),
        " no username",
      ]
    end
  end

  defp usernames(%Commit{usernames: names}) do
    names
    |> Enum.map(fn (name) ->
         if Commit.bot?(name) do
           [
             content_tag(:i, "", class: "fas fa-robot text-gray-dark"),
             " ",
             Commit.botless_username(name),
           ]
         else
           name
         end
       end)
    |> Enum.map(& content_tag(:b, &1))
    |> Enum.intersperse(" and ")
  end
end
