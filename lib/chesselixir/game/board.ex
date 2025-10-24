defmodule Chesselixir.Game.Board do
  @moduledoc """
  Simplified board representation and helper functions.
  """

  @files ~w(a b c d e f g h)
  @ranks 1..8

  defstruct pieces: %{}

  @type square :: String.t()
  @type t :: %__MODULE__{pieces: %{square() => String.t()}}

  # starting position
  @start_fen "rn.../pp.../......../......../......../......../PP.../RN... w KQkq - 0 1"
  # use a full FEN later — right now we build manually for demo

  def start_fen, do: @start_fen

  def start_board do
    %__MODULE__{
      pieces: %{
        "a2" => "♙", "b2" => "♙", "c2" => "♙", "d2" => "♙", "e2" => "♙", "f2" => "♙", "g2" => "♙", "h2" => "♙",
        "a7" => "♟", "b7" => "♟", "c7" => "♟", "d7" => "♟", "e7" => "♟", "f7" => "♟", "g7" => "♟", "h7" => "♟",
        "a1" => "♖", "b1" => "♘", "c1" => "♗", "d1" => "♕", "e1" => "♔", "f1" => "♗", "g1" => "♘", "h1" => "♖",
        "a8" => "♜", "b8" => "♞", "c8" => "♝", "d8" => "♛", "e8" => "♚", "f8" => "♝", "g8" => "♞", "h8" => "♜"
      }
    }
  end

  def from_fen(_fen), do: start_board()
  def to_fen(_board), do: @start_fen

  def move_piece(%__MODULE__{pieces: pieces} = board, from, to) do
    case Map.fetch(pieces, from) do
      {:ok, piece} ->
        new_pieces =
          pieces
          |> Map.delete(from)
          |> Map.put(to, piece)

        {:ok, %{board | pieces: new_pieces}}

      :error ->
        {:error, :no_piece}
    end
  end

  # UI helpers
  def square(file, rank), do: Enum.at(@files, file - 1) <> Integer.to_string(rank)
  def glyph(%__MODULE__{pieces: pieces}, sq), do: Map.get(pieces, sq, "")
  def css(file, rank), do: if(rem(file + rank, 2) == 0, do: "light", else: "dark")
end
