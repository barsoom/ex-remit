defmodule Remit.UsersFromCommitTrailers do
  @moduledoc false
  @mention_re ~r/
  <(.*)>
  /ix

  def call(commit) when is_binary(commit.message) do
    commit.message
    |> String.split("\n")
    |> Enum.filter(fn line -> String.starts_with?(line, "Co-authored-by") end)
    |> Enum.flat_map(fn trailer -> Regex.scan(@mention_re, trailer, capture: :all_but_first) end)
    |> List.flatten()
  end

  def call(_commit), do: []
end
