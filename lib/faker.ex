defmodule Faker do
  def human_name do
    Enum.random(["Fred", "Ada", "Enya", "Snorre", "Harry", "Maud"]) <>
      " " <>
      Enum.random(["Skog", "Lund", "Flod", "Träd", "Fisk"]) <>
      Enum.random(["berg", "kvist", "bäck", "zon", "plopp", "is"])
  end

  def number, do: Enum.random(1..99999)

  def sha(i \\ number()) do
    :crypto.hash(:sha, to_string(i)) |> Base.encode16() |> String.downcase()
  end

  def username do
    Enum.random(["foo", "bar", "baz", "hat", "frog", "snake", "bat"]) <>
      Enum.random(["cat", "dog", "master", "wrangler"])
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
