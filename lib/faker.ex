defmodule Faker do
  def human_name do
    Enum.random(["Fred", "Ada", "Enya", "Snorre", "Harry", "Maud"]) <>
      " " <>
      Enum.random(["Skog", "Lund", "Flod", "Träd", "Fisk"]) <>
      Enum.random(["berg", "kvist", "bäck", "zon", "plopp", "is"])
  end

  def sha(i \\ Enum.random(1..999)) do
    :crypto.hash(:sha, to_string(i)) |> Base.encode16 |> String.downcase
  end

  def email(i \\ Enum.random(1..999)) do
    "user#{i}@example.com"
  end

  def repo do
    Enum.random(["cat", "dog", "fish", "man", "tiger", "power"]) <>
      Enum.random(["pics", "ballads", "odes"])
  end

  def message do
    Enum.random(["I", "We"]) <> " " <>
      Enum.random(["fixed", "broke", "invented", "inverted", "killed", "loved"]) <> " " <>
      Enum.random(["the thing", "your mom", "the world", "a man", "the truth", "a partridge in a pear tree"])
  end
end
