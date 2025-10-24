defmodule Chesselixir.Games.Move do
  use Ecto.Schema
  import Ecto.Changeset

  schema "moves" do
    field :uci, :string
    field :san, :string
    field :fen_after, :string
    field :number, :integer

    belongs_to :game, Chesselixir.Games.Game, type: :binary_id
    timestamps()
  end

  def changeset(move, attrs) do
    move
    |> cast(attrs, [:game_id, :uci, :san, :fen_after, :number])
    |> validate_required([:game_id, :uci, :fen_after])
  end
end
