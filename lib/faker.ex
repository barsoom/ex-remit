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

  def team do
    Enum.random(["team-octopus", "team-cat", "team-lion"])
  end

  def message do
    Enum.random([
      "Fixed",
      "Broke",
      "Reverted",
      "Removed",
      "Refactored",
      "Simplified",
      "Optimised",
      "Suboptimised",
      "Redesigned",
      "Mocked up",
      "Uploaded",
      "Threw out",
      "Decoupled",
      "Tightly coupled"
    ]) <>
      " " <>
      Enum.random([
        "the header",
        "the footer",
        "the architecture",
        "our design system",
        "the UX",
        "the front-end",
        "the back-end",
        "the pipeline",
        "CI",
        "production",
        "the sitemap"
      ]) <>
      " " <>
      Enum.random(["", "", "", "", "", "", "", "", "", "", "with monads", "in the cloud"])
  end

  def message_with_co_authors(message, authors) do
    Enum.reduce(authors, message, fn author, trailer ->
      trailer <> ~s(\nCo-authored-by: #{author} <#{author}@users.noreply.github.com>)
    end)
  end

  def comment do
    Enum.random([
      "Looks great!",
      "Ship it!",
      "Sensational!",
      "Needs more cowbell."
    ])
  end

  def paragraph_comment do
    sentences = [
      "This looks really solid to me.",
      "I had a quick look and the logic seems sound.",
      "Nice refactor here, much cleaner than before.",
      "One thing I was wondering about: should we handle the edge case where the list is empty?",
      "The naming is clear and the intent is obvious.",
      "I think this could be extracted into a helper at some point, but for now it's fine.",
      "Left a note on Slack about this too, just so you know.",
      "Let me know if you want me to pair on the next step.",
      "Happy with the direction, just minor style thing on line 3.",
      "Good catch on the N+1 — wouldn't have noticed that.",
      "This matches what we discussed in the standup.",
      "I'd love to see a test for the nil case eventually.",
      "Merging this unblocks the next step in the flow.",
      "Super clean, ship it."
    ]

    count = Enum.random(3..4)
    sentences |> Enum.shuffle() |> Enum.take(count) |> Enum.join(" ")
  end
end
