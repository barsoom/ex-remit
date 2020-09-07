defmodule Faker do
  @moduledoc """
  Generate fake values for dev and test purposes.
  """

  def number, do: Enum.random(1..99_999)

  def sha(i \\ number()) do
    :crypto.hash(:sha, to_string(i)) |> Base.encode16() |> String.downcase()
  end

  def username do
    if Enum.random(0..10) == 0 do
      # This seems to be a naming convention. At least for "dependabot[bot]"
      Enum.random(["pretendabot", "bananabot", "marvin", "robbie", "robocop", "r2d2"]) <>
        "[bot]"
    else
      Enum.random(["foo", "bar", "baz", "hat", "frog", "snake", "bat"]) <>
        Enum.random(["cat", "dog", "master", "wrangler"])
    end
  end

  def email, do: "email#{number()}@example.com"

  def repo do
    Enum.random(["cat", "dog", "fish", "man", "tiger", "power", "golden_", "tiki"]) <>
      Enum.random(["pics", "ballads", "odes", "leaks", "hacks"])
  end

  def message do
    Enum.random(["Fixed", "Broke", "Reverted", "Removed", "Refactored", "Simplified", "Optimised", "Suboptimised", "Redesigned", "Mocked up", "Uploaded", "Threw out", "Decoupled", "Tightly coupled"]) <>
      " " <>
      Enum.random(["the header", "the footer", "the architecture", "our design system", "the UX", "the front-end", "the back-end", "the pipeline", "CI", "production", "the sitemap"]) <>
      " " <>
      Enum.random(["", "", "", "", "", "", "", "", "", "", "with monads", "in the cloud"])
  end

  def comment do
    Enum.random([
      "Looks great!",
      "Ship it!",
      "Sensational!",
      "Needs more cowbell.",
    ])
  end
end
