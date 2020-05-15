defmodule Remit.Author do
  use Ecto.Schema
  import Ecto.Changeset

  schema "authors" do
    field :email, :string
    field :name, :string
    field :username, :string

    timestamps()
  end

  @doc false
  def changeset(author, attrs) do
    author
    |> cast(attrs, [:name, :email, :username])
    |> validate_required([:name, :email, :username])
  end
end
