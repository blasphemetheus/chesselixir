defmodule Chesselixir.Game.Engine do
  @moduledoc """
  Minimal chess engine for LiveView demo.

  Supports:
    - Board initialization
    - Basic move application (no rule enforcement yet)
    - Stubbed legal_moves/2 for future expansion
  """

  alias Chesselixir.Game.Board

  @type square :: String.t()
  @type move :: {square(), square()}
  @type board :: Board.t()

  @spec legal_moves(board, square) :: [square]
  def legal_moves(_board, _from_sq) do
    # TODO: replace with real move generation later
    []
  end

  @spec apply_move(board, move) :: {:ok, board} | {:error, term()}
  def apply_move(board, {from, to}) do
    case Board.move_piece(board, from, to) do
      {:ok, new_board} -> {:ok, new_board}
      {:error, reason} -> {:error, reason}
    end
  end
end
