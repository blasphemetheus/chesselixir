defmodule Chesselixir.Games do
  import Ecto.Query
  alias Chesselixir.Repo
  alias Chesselixir.Games.{Game, Move}
  alias Chesselixir.Game.Board

  @start_fen "rn.../pp... ... w KQkq - 0 1" # use real start FEN

  def create_game(attrs \\ %{}) do
    %Game{fen: Board.start_fen()}
    |> Game.changeset(attrs)
    |> Repo.insert()
  end

  def get!(id), do: Repo.get!(Game, id)

  def apply_move(id, from, to, board_after) do
    Repo.transaction(fn ->
      game = Repo.get!(Game, id)
      fen  = Board.to_fen(board_after)
      game = Ecto.Changeset.change(game, fen: fen) |> Repo.update!()
      # optional save move:
      # %Move{game_id: game.id, uci: from<>to, fen_after: fen} |> Repo.insert!()
      game
    end)
    |> case do
      {:ok, game} -> {:ok, game}
      {:error, reason} -> {:error, reason}
    end
  end
end
