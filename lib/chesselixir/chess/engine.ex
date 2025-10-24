# lib/my_app/chess/engine.ex
defmodule MyApp.Chess.Engine do
  @moduledoc """
  Thin adapter over the gchess core. Phoenix and LiveView only talk to this module.
  Replace the TODOs to call your real gchess modules.
  """

  alias MyApp.Chess.Types

  @type coord :: {integer(), integer()}  # {file, rank} -> {1..8, 1..8}
  @type state :: any()

  @doc "Start a new game state"
  @spec new_game() :: state()
  def new_game() do
    # TODO: call into your controller/model initializer.
    # Example: GChess.Controller.new_game()
    initial_board()
  end

  @doc "Return a 2D 8x8 representation of pieces for rendering"
  @spec board(state()) :: list(list(Types.piece() | nil))
  def board(state) do
    # TODO: translate gchess state to a 2D list for the UI
    state
  end

  @doc "Compute legal moves for a given square (optional: for UI hints)"
  @spec legal_moves(state(), coord()) :: [coord()]
  def legal_moves(_state, _from), do: []

  @doc "Attempt a move. Return {:ok, new_state} or {:illegal, reason}"
  @spec move(state(), coord(), coord()) :: {:ok, state()} | {:illegal, String.t()}
  def move(state, {fx, fy}, {tx, ty}) do
    # TODO: delegate to gchess. For now, do a naive 'move' in a 2D list.
    if in_bounds({fx, fy}) and in_bounds({tx, ty}) do
      new_state =
        state
        |> List.update_at(8 - fy, fn row ->
          row
          |> List.update_at(fx - 1, fn _ -> nil end)
        end)
        |> List.update_at(8 - ty, fn row ->
          row
          |> List.update_at(tx - 1, fn _ -> piece_at(state, {fx, fy}) end)
        end)

      {:ok, new_state}
    else
      {:illegal, "out of bounds"}
    end
  end

  @doc "Return the piece at a coordinate"
  @spec piece_at(state(), coord()) :: Types.piece() | nil
  def piece_at(state, {x, y}) do
    row = Enum.at(state, 8 - y)
    row && Enum.at(row, x - 1)
  end

  defp in_bounds({x, y}), do: x in 1..8 and y in 1..8

  # Temporary starting board (replace with your gchess init)
  defp initial_board() do
    # pieces are atoms like :wP, :wN, :wB, :wR, :wQ, :wK and black variants
    pawns_w = for _ <- 1..8, do: :wP
    pawns_b = for _ <- 1..8, do: :bP
    empty   = for _ <- 1..8, do: nil

    [
      [:bR, :bN, :bB, :bQ, :bK, :bB, :bN, :bR],
      pawns_b,
      empty, empty, empty, empty,
      pawns_w,
      [:wR, :wN, :wB, :wQ, :wK, :wB, :wN, :wR]
    ]
  end
end
