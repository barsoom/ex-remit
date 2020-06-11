defmodule RemitWeb.CommitComponent do
  use RemitWeb, :live_component
  alias Remit.{Commit, Utils}

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
