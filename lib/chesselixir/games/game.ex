defmodule Chesselixir.Games.Game do
  use Ecto.Schema
  import Ecto.Changeset

  @primary_key {:id, :binary_id, autogenerate: true}
  @foreign_key_type :binary_id
  schema "games" do
    field :fen, :string
    field :status, :string, default: "playing"
    field :white_id, :binary_id
    field :black_id, :binary_id

    timestamps()
  end

  def changeset(game, attrs) do
    game
    |> cast(attrs, [:fen, :status, :white_id, :black_id])
    |> validate_required([:fen, :status])
  end
end
