defmodule Chessboard do
  @moduledoc """
  This is an implementation of a chess board.
  There's two types of functions right now, those that use the Board struct and those
  that use the list structure that the board is stored in.

  The Board struct is probably the most useful, but it will fundamentally rely on the list structure
  in the placements field of the struct. placements is a list of lists, where each list is a rank.
  """

  ## IMPORTS ##
  require BoardError
  import Board.Utils
  import Location
  import Moves
  #import MoveError

  ## MODULE ATTRIBUTES ## (useful for constants among other things)
  @maxSide 8
  @minSide 3
  @firstColor :orange
  @secondColor :blue
  @piecetypes [:pawn, :bishop, :knight, :rook, :queen, :king]
  #@move_only [:sprint, :march, :castle, :promote]
  #@castling_priveleges [:short, :long, :both, :none, :left, :right]
  # short and long and left and right are disagreeing notions of how a board's orientation works,
  # but it's simple enough to support both, so I'm going to (it's a bad idea)
  # short is always kingside, long is always queenside, but if you're orange,
  # queenside is to the left, while it's on the right if blue
  # orange kingside is to the right, blue kingside to the left

  ## GUARDS ## (preconditions for fns)
  # checks if a column and row are in the valid lengths for the board
  defguard good_col_and_row(columns, rows) when @maxSide >= columns and columns >= @minSide and @maxSide >= rows and rows >= @minSide
  # checks if a piecetype is real
  defguard valid_piecetype(pieceType) when pieceType in @piecetypes
  # checks if color is real
  defguard valid_color(color) when color in [@firstColor, @secondColor]

  @doc """
  Define %Chessboard{} struct.

  It has placements (the implementation of locations), a representation of the
  order of the two colors (order), some way of checking whether the game is over (stalemate, checkmate),
  a way to check for en passant, and a way to check for castling.

  This is the struct that represents the board. It has a list of lists, where each list is a rank.
  And each item in the rank is a tuple of atoms = {color, pieceType} or an atom (:mt)

  This struct will probably be added to with the FEN stuff as I create it
  """
  defstruct placements: [], order: [@firstColor, @secondColor], impale_square: :noimpale, first_castleable: :both, second_castleable: :both, halfmove_clock: 0, fullmove_number: 1
  ## %Chessboard{placements: rec2DList(columns, rows)}

  ### FUNCTIONS ###

  def promotingOptions() do
    [:bishop, :knight, :rook, :queen]
  end

  @doc """
  Given an end location and a piecetype, return whether a move requires promotion (most do not).
  """
  def move_requires_promotion?(:blue, :pawn, {_col, 1} = _end_loc), do: true
  def move_requires_promotion?(:orange, :pawn, {_col, 8} = _end_loc), do: true
  def move_requires_promotion?(_any_piece_color, _any_other_piece_type, _any_end_loc), do: false

  @doc """
  insert a piece into the placements list of lists given a location ie {:a, 1}
  as well as a piece color and pieceType. All these need to be valid.
  Also pawns can't go in the first or last rank because rules.
  Can't place a piece in a non-empty zone.
  """
  def placePiece(_brd, _f_loc, _p_clr, pieceType) when not valid_piecetype(pieceType) do
    raise ArgumentError, message: "not a valid piecetype: #{inspect(pieceType)}"
  end

  def placePiece(_board, _formal_location, pieceColor, _pieceType) when not valid_color(pieceColor) do
    raise ArgumentError, message: "color of piece invalid. Got: #{inspect(pieceColor)}"
  end

  def placePiece(board, f_loc, p_clr, :pawn) do
    dimensions = board |> boardSize()
    if inRankUpZone(dimensions, f_loc, p_clr) do
      raise BoardError, message: "trying to place pawn in rankUpZone: invalid loc #{inspect(f_loc)} color #{inspect(p_clr)}"
    end
    if inKingRank(dimensions, f_loc, p_clr) do
      raise BoardError, message:  "trying to place pawn in king rank: invalid loc #{inspect(f_loc)} color #{inspect(p_clr)}"
    end
    replace_at(board, f_loc, {p_clr, :pawn})
  end

  def placePiece(board, formal_location, pieceColor, pieceType) do
    unless fLocationIsEmpty(board, formal_location) do
      raise BoardError, message: "cannot place a piece in a non-empty zone"
    end
    # "nice! the zone is empty"

    replace_at(board, formal_location, {pieceColor, pieceType})
  end

  @doc """
  given placements, a location, and a playerColor.
  returns a new placements with the indicated replaced with an :mt
  """
  def remove_at(board, location) do
    board
    |> replace_at(location, :mt)
  end

  @doc """
  given placements, a location, and tuple of color and piecetype,
  returns a new group of placements, with the replacements made
  """
  def replace_at(board, {f_col, f_row} = f_location, {pieceColor, pieceType}) when is_atom(f_col) and is_integer(f_row) do
    replace_at(board, dumbLocation(f_location), {pieceColor, pieceType})
  end

  def replace_at(board, {f_col, f_row} = f_location, :mt)  when is_atom(f_col) and is_integer(f_row) do
    replace_at(board, dumbLocation(f_location), :mt)
  end

  # dumb location is tuple {int, int}
  def replace_at(board, {row, col}, :mt) when is_integer(row) and is_integer(col) do
    rank = board |> Board.Utils.reverseRanks |> Enum.at(row)
    new_rank = List.replace_at(rank, col, :mt)

    Board.Utils.reverseRanks(List.replace_at(Board.Utils.reverseRanks(board), row, new_rank))
  end

  def replace_at(board, {row, col}, {pieceColor, pieceType}) when is_integer(row) and is_integer(col) do
    rank = board |> Board.Utils.reverseRanks |> Enum.at(row) # [[:mt,:mt,:mt],[:mt,:mt,:mt],[:mt,:mt,:mt]]
    new_rank = List.replace_at(rank, col, {pieceColor, pieceType})

    Board.Utils.reverseRanks(List.replace_at(Board.Utils.reverseRanks(board), row, new_rank))
  end

  def fLocationIsEmpty(board, {_formal_col, _formal_row} = formal_location) do
    dLocationIsEmpty(board, dumbLocation(formal_location))
  end

  ## the actual implementation !!!
  def dLocationIsEmpty(board, d_location) do
    case get_at(board, d_location) do
      :mt -> true
      _ -> false
    end
  end

  @doc """
  Given a string, make a Chessboard struct and give it a placements parsed from the string
  """
  def instil(str), do: %Chessboard{placements: str |> Parser.parseBoardFromString()}


  @doc """
  We need to be able to grab what's at a location based on the list
  structure that it is stored on (the {row, col} interpretation) {ie {3, 0}
  AND we need to be able to grab what's at a given formal location
  (the {col, row} interpretation){ie {:a, 1}}
  """
  def get_at(placements, {row, col}) when is_integer(row) and is_integer(col) do
    #OH MY, THIS IS WORRYING AT BEHAVIOR, I FORGOT ABOUT THE REVERSING SHENANIGANS
    # MUST REFACTOR BECAUSE WOW, NOT INTUITIVE AT ALL, fortunately
    # ill just lock it behind this black box of `at` and refactor l8r
    # dealing only with formal locations until then

    #rank = board |> Enum.at(row)
    #Enum.at(rank, col)
    rank = Board.Utils.reverseRanks(placements) |> Enum.at(row)
    Enum.at(rank, col)
  end

  def get_at(board, {f_col, f_row} = formal_location) when is_integer(f_row) and is_atom(f_col) do
    get_at(board, dumbLocation(formal_location))
  end

  @doc """
  given a board, returns the board size as a dimensions matrix (so like {3, 4} for 3 columns, 4 rows)
  """
  def boardSize(board) do
    rows = length(board)

    cols = case rows do
      0 -> 0
      _num -> length(List.first(board))
    end

    check = fn (col, row) when good_col_and_row(col, row) -> {col, row} end

    check.(cols, rows)
  end

  # Location: {:a, 1 } {0, 0} (a dumb location would be {0, 7})
  @doc """
  returns whether the given location is in the rankupZone for that piece color given a boardSize dimension matrix (col then row)
  """
  def inRankUpZone(board_dimensions, location, pieceColor) do
    # rank up zone is the last and top most for orange (equivalent of white in chess)

    {_columns, rows} = board_dimensions
    {_specific_col, specific_row} = location

    case pieceColor do
      @firstColor -> rows == specific_row # in specific row which is specified in board_dimensions
      @secondColor -> specific_row == 1 # in specific row which must be 1 (or 0 if start from 0)
    end
  end

  @doc """
  returns whether the given location is in the king rank for that piece color given
  a boardSize dimension matrix (col then row)
  The king rank is the first row for the first player and last row for the second.
  The row that appears closest to the player when playing across the board.
  """
  def inKingRank({_num_cols, num_rows} = _dimensions, {_col, row} = _loc, p_clr) do
    case p_clr do
      @firstColor -> 1 == row
      @secondColor -> num_rows == row
    end
  end

  @doc """
  given placements, loc and a playerColor
  return the placement at the loc behind the loc provided
  """
  def behind_at(placements, loc, color) do
    get_at(placements, behind(loc, color))
  end

  def behind({e_col, e_row}, :orange) do
    {e_col, e_row - 1}
  end

  def behind({e_col, e_row}, :blue) do
    {e_col, e_row + 1}
  end

  @doc """
  given a playerColor and moveType,
  return the spot in the castle where the rook is
  """
  def rookspot(color, :longcastle), do: long_rookspot(color)
  def rookspot(color, :shortcastle), do: short_rookspot(color)

  def short_rookspot(:orange), do: {:h, 1}
  def short_rookspot(:blue), do: {:h, 8}

  def long_rookspot(:blue), do: {:a, 8}
  def long_rookspot(:orange), do: {:a, 1}

  @doc """
  given placements, and a start and end location,
  return the travel spot between them that the king passes through on a castle
  """
  def castle_travel_spot({s_col, s_row}, {e_col, _e_row}) when e_col != s_col do
    new_col = cond do
      e_col > s_col -> column_to_int(e_col) - 1 |> int_to_column()
      e_col < s_col -> column_to_int(e_col) + 1 |> int_to_column()
    end

    {new_col, s_row}
  end

  @doc """
  A collection of validation functions, ENSURES
  They return true if validated and raise a MoveError otherwise
  """
  def ensurePlacementNotEmpty(placement) do
    case placementNotEmpty(placement) do
      true -> true
      false -> raise MoveError, message: "moving piece is empty, cannot move empty"
    end
  end

  def placementNotEmpty(placement), do: placement != :mt

  def ensurePlacementAgreesWithProvidedInfo({moving_color, moving_type} = moving_piece, playerColor, pieceType) do
    case placementAgreesWithProvidedInfo({moving_color, moving_type}, playerColor, pieceType) do
      true -> true
      false -> raise MoveError,
        message: "Mismatch: the placement of the piece at the LOCATION and the provided info do not match, PROVIDED: #{
        inspect({playerColor, pieceType})} PRESENT : #{inspect(moving_piece)}"
    end
  end

  def placementAgreesWithProvidedInfo({moving_color, moving_type} = moving_piece, playerColor, pieceType) do
    is_tuple(moving_piece) and moving_color == playerColor and moving_type == pieceType
  end

  def ensureNotTakingOwnPiece({e_color, e_type}, moving_color) do
    case notTakingOwnPiece({e_color, e_type}, moving_color) do
      true -> true
      false -> raise MoveError, message: "Cannot take your own piece"
    end
  end

  def notTakingOwnPiece({e_color, _e_type}, moving_color) do
    e_color != moving_color
  end

  def ensureMoveTypeValid(movetype, start_loc, end_loc, playerColor, pieceType) do
    case moveTypeValid(movetype) do
      true -> true
      false -> raise MoveError,
        message: "invalid move, STARTING #{inspect(start_loc)}  GOING TO #{
        inspect(end_loc) } with COLOR: #{inspect(playerColor)} PIECETYPE #{
        inspect(pieceType)}"
    end
  end

  def moveTypeValid(movetype), do: movetype != :invalid

  def ensurePromoteTypeValid(pr_type, movetype) do
    case promoteTypeValid(pr_type, movetype) do
      true -> true
      false -> raise MoveError, message: "Trying to promote invalidly, PROMOTE_TYPE : #{
        inspect(pr_type)}, MOVETYPE : #{inspect(movetype)}"
    end
  end

  def promoteTypeValid(pr_type, movetype) do
    case pr_type do
      :nopromote -> movetype not in [:promote, :promotecapture]
      _other -> pr_type in [:knight, :queen, :rook, :bishop] and  movetype in [:promote, :promotecapture]
    end
  end

  def ensurePassivityMatchesResult(movetype, end_loc_placement) do
    case passivityMatchesResult(movetype, end_loc_placement) do
      true -> true
      false -> cond do
        movetype in [:capture, :promotecapture] ->
          raise MoveError, message: "Move #{inspect(movetype)}cannot be performed as there is no piece to take"
        movetype in [:march, :sprint, :promote] ->
          raise MoveError, message: "Move #{inspect(movetype)} cannot be performed because you cannot take with this move"
      end
    end
  end

  def passivityMatchesResult(moveType, end_loc_placement) do
    cond do
      moveType in [:capture, :promotecapture] ->
        captureIsTaking(moveType, end_loc_placement)
      moveType in [:march, :sprint, :promote] ->
        passiveIsMoving(moveType, end_loc_placement)
    end
  end

  def captureIsTaking(_movetype, :mt), do: false
  def captureIsTaking(_movetype, {_color, _type}), do: true
  def passiveIsMoving(_movetype, :mt), do: true
  def passiveIsMoving(_movetype, {_color, _type}), do: false

  def ensureRushingMovesHavePiecesInBetween(moveType, placements, end_loc, start_loc) do
    case rushingMovesHavePiecesInBetween(moveType, placements, end_loc, start_loc) do
      false -> false
      true -> raise MoveError, message:  "move #{moveType
        } invalid as there is at least one piece in the way"
    end
  end

  def rushingMovesHavePiecesInBetween(moveType, placements, end_loc, start_loc) do
    if moveType in [:vertical, :diagonal, :horizontal, :longcastle, :shortcastle, :sprint] do
      blocked(placements, end_loc, start_loc)
    else
      false
    end
  end

  def ensureImpalingCaptureInFrontOfEnemyPawn(movetype, impalable_loc, placements, end_loc, player_color) do
    case impalingCaptureInFrontOfEnemyPawn(movetype, impalable_loc, placements, end_loc, player_color) do
      true -> true
      false -> raise MoveError, message: "Trying to impale but not in front of enemy pawn"
    end
  end

  def impalingCaptureInFrontOfEnemyPawn(movetype, impalable_loc, placements, end_loc, playerColor) do
    if impalable_loc == end_loc and movetype == :capture do
      in_front_of_enemy_pawn(placements, end_loc, playerColor)
    else
      true
    end
  end

  @doc """
  Given a location, a color, and placements, returns
  whether the location is in front of an enemy pawn

  returns whether the location provided is in front of a pawn
  on the provided placements, with the provided pieceColor
  """
  def in_front_of_enemy_pawn(placements, loc, color) do
    opponent = otherColor(color)
    case behind_at(placements, loc, color) do
      {^opponent, :pawn} -> true
      _any -> false
    end
  end

  def ensureCastleNotSpent(movetype, castle_dirs) do
    case castleNotSpent(movetype, castle_dirs) do
      true -> true
      false -> raise MoveError, message: "Not castleable with Available Castles: #{inspect(castle_dirs)}, and movetype #{movetype}."
    end
  end

  def castleNotSpent(:longcastle, castle_dirs) do
    castle_dirs in [:queenside, :both]
  end

  def castleNotSpent(:shortcastle, castle_dirs) do
    castle_dirs in [:kingside, :both]
  end

  def ensureKingCheckDoesntDisruptCastle(movetype, board, player_color) do
    case kingCheckDoesntDisruptCastle(movetype, board, player_color) do
      true -> true
      false -> raise MoveError, message: "Not castleable, king in check"
    end
  end

  def kingCheckDoesntDisruptCastle(movetype, board, player_color) do
    movetype in [:longcastle, :shortcastle] and not kingThreatened(board, player_color)
  end

  @doc """
  Given a board and a color, returns a boolean representing whether the king is threatened,
  avoiding infinite recursion (by making a move and checking it with this fn say) :)
  """
  def kingThreatened(board, player_color) do
    king_loc = findKing(board.placements, player_color)
    # taking inspiration from
    # https://github.com/official-stockfish/Stockfish/blob/0405f3540366cc16245d51531881c55d3726c8b5/src/position.cpp#L338
    # separating out my isCheck function from the checking if the next move makes check happen
    # this interior check for check will look at the attackers_of (attackers_to in stockfish)
    # then filter them for those on my side
    enemy_attackers = attackers_of(board, king_loc)
    |> reject_same_color(player_color)

    enemy_attackers_are_zero = enemy_attackers |> length() == 0

    not enemy_attackers_are_zero
  end

  def reject_same_color(list_loc_placements, player_color) do
    list_loc_placements
    |> Enum.reject(fn
      {_loc, {^player_color, _piece_type}} -> true
      {_loc, {_other_color, _piece_type}} -> false
    end)
  end

  @doc """
  Given a board and a location, return a list of tuples of attacking_loc and attacking_placement,
  where the attacking_placement is a piecetype that can attack that square, but ignore color
  """
  def attackers_of(board, location) do
    placements = board.placements
    color = case get_at(placements, location) do
      :mt -> raise ArgumentError, message: "trying to find attackers_of an open square"
      {color, _piece_type} -> color
    end

    line = fn
      {_loc, {_piececolor, :queen}} -> true
      {_loc, {_piececolor, :pawn}} -> false
      {_loc, {_piececolor, :knight}} -> false
      {_loc, {_piececolor, :king}} -> false
      {_loc, {_piececolor, :bishop}} -> false
      {_loc, {_piececolor, :rook}} -> true
    end

    bishop_queen = fn
      {_loc, {_piececolor, :queen}} -> true
      {_loc, {_piececolor, :pawn}} -> false
      {_loc, {_piececolor, :knight}} -> false
      {_loc, {_piececolor, :king}} -> false
      {_loc, {_piececolor, :bishop}} -> true
      {_loc, {_piececolor, :rook}} -> false
    end
    peer_one_in_every_direction(location, color, placements) ++
    peer_horse_moves(location, color, placements) ++
    [scan(:right, location, color, placements, line), scan(:left, location, color, placements, line),
    scan(:up, location, color, placements, line), scan(:down, location, color, placements, line),
    scan(:sidleright, location, color, placements, bishop_queen), scan(:veerright, location, color, placements, bishop_queen),
    scan(:sidleleft, location, color, placements, bishop_queen), scan(:veerleft, location, color, placements, bishop_queen)]
    |> Enum.reject(fn
      [] -> true
      :ob -> true
      {_loc, :mt} -> true
      _any -> false
    end)
    |> Enum.uniq()
  end

  @doc """
  Rejects out of bounds, else lets through
  """
  def reject_ob(list) when is_list(list) do
    list
    |> Enum.filter(fn
      :ob -> false
      {_col, _loc} -> true
    end)
  end

  def reject_ob(:ob), do: :reject
  def reject_ob(_any), do: :strange

  @doc """
  Given a list, a function to apply, and placements
  """
  def process({_col, _row} = loc, function, placements) when loc |> is_tuple() do
    new = {loc, get_at(placements, loc)}
    case new |> function.() do
      true -> new
      false -> []
    end
  end

  def process(list, function, placements) when list |> is_list() do
    #Enum.map(fn item -> reject_ob_and_process(item, function, placements))
    list
    |> Enum.map(fn
      {col, row} -> {{col, row}, get_at(placements, {col, row})}
    end)
    |> Enum.reject(fn
      {{_col, _row}, :mt} -> true
      _any -> false
     end)
    |> Enum.filter(function)
  end

  def peer_one_in_every_direction(loc, color, placements) do

    line_short = fn
      {_loc, {_piececolor, :queen}} -> true
      {_loc, {_piececolor, :pawn}} -> false
      {_loc, {_piececolor, :knight}} -> false
      {_loc, {_piececolor, :king}} -> true
      {_loc, {_piececolor, :bishop}} -> false
      {_loc, {_piececolor, :rook}} -> true
    end

    left = sidestep(loc, color, :left)
    right = sidestep(loc, color, :right)
    forw = forwardstep(loc, color)
    backs = backstep(loc, color)

    sides = [left, right, forw, backs]
    |> reject_ob
    |> process(line_short, placements)

    front_diag = fn
      {_loc, {_piececolor, :queen}} -> true
      {_loc, {_piececolor, :pawn}} -> true
      {_loc, {_piececolor, :knight}} -> false
      {_loc, {_piececolor, :king}} -> true
      {_loc, {_piececolor, :bishop}} -> true
      {_loc, {_piececolor, :rook}} -> false
    end
    front_diag_list = [duck(loc, color, :left), duck(loc, color, :right)]
    |> reject_ob
    |> process(front_diag, placements)

    back_diag = fn
      {_loc, {_piececolor, :queen}} -> true
      {_loc, {_piececolor, :pawn}} -> false
      {_loc, {_piececolor, :knight}} -> false
      {_loc, {_piececolor, :king}} -> true
      {_loc, {_piececolor, :bishop}} -> true
      {_loc, {_piececolor, :rook}} -> false
    end
    back_diag_list = [roll(loc, color, :left), roll(loc, color, :right)]
    |> reject_ob
    |> process(back_diag, placements)

    front_diag_list ++ sides ++ back_diag_list
  end

  def peer_horse_moves(loc, color, placements) do

    horse  = fn
      {_loc, {_piececolor, :queen}} -> false
      {_loc, {_piececolor, :pawn}} -> false
      {_loc, {_piececolor, :knight}} -> true
      {_loc, {_piececolor, :king}} -> false
      {_loc, {_piececolor, :bishop}} -> false
      {_loc, {_piececolor, :rook}} -> false
    end

    [gallop(loc, color, :left), gallop(loc, color, :right),
    trot(loc, color, :left), trot(loc, color, :right),
    rear(loc, color, :left), rear(loc, color, :right),
    turnabout(loc, color, :left), turnabout(loc, color, :right)]
    |> reject_ob()
    |> process(horse, placements)
  end

  def atom_to_function(:right, loc, color), do: sidestep(loc, color, :right)
  def atom_to_function(:left , loc, color), do: sidestep(loc, color, :left)
  def atom_to_function(:up , loc, color), do: forwardstep(loc, color)
  def atom_to_function(:down , loc, color), do: backstep(loc, color)
  def atom_to_function(:sidleright , loc, color), do: roll(loc, color, :right)
  def atom_to_function(:sidleleft , loc, color), do: roll(loc, color, :left)
  def atom_to_function(:veerleft , loc, color), do: duck(loc, color, :left)
  def atom_to_function(:veerright , loc, color), do: duck(loc, color, :right)

  def scan(direction, {_col, _row} = loc, color, placements, function) do
        new = atom_to_function(direction, loc, color)
        if new == :ob do
          []
        else
          new_placement = get_at(placements, new)
          case new_placement do
            :mt ->
              scan(direction, new, color, placements, function)
            {_color, _type} ->

              case {new, new_placement} |> function.() do
                true -> {new, new_placement}
                false -> []
              end
          end
        end
  end

  def ensureKingNotPassingThroughCheckForCastle(playerColor, moveType, board, travel_spot) do
    case kingPassingThroughCheckForCastle(playerColor, moveType, board, travel_spot) do
      false -> true
      true -> raise MoveError, message: "In Between Castling Location #{inspect(travel_spot)
      } is threatened by the opposing player's pieces, castling in this direction impossible for now"
    end
  end

  def kingPassingThroughCheckForCastle(playerColor, moveType, board, travel_spot) do
    (moveType == :shortcastle or moveType == :longcastle) and
    travel_spot in threatens(board, otherColor(playerColor))
  end

  def ensureRookspotContainsRookForCastle(playerColor, placements, rook_spot) do
    case rookspotContainsRookForCastle(playerColor, placements, rook_spot) do
      true -> true
      false -> raise MoveError, message: "uncastleable because no rook at #{inspect(rook_spot)}"
    end
  end

  def rookspotContainsRookForCastle(playerColor, placements, rook_spot) do
    case get_at(placements, rook_spot) do
      {^playerColor, :rook} -> true
      _ -> false
    end
  end

  def ensureNoPiecesBetweenRookAndKingForCastle(placements, start_loc, rook_spot) do
    case piecesBetweenRookAndKingForCastle(placements, start_loc, rook_spot) do
      false -> true
      true -> raise MoveError, "castle invalid as there is a piece in the way"
    end
  end

  def piecesBetweenRookAndKingForCastle(placements, {s_col, s_row} = _start_loc, {r_col, r_row} = _rook_spot) when s_row == r_row do
    pieces_between(placements, s_row, {column_to_int(s_col), column_to_int(r_col)}) |> length() == 0
  end

  def ensureNewBoardDoesNotPutYouInCheck(new_board, playerColor) do
    case newBoardPutsYouInCheck(new_board, playerColor) do
      false -> true
      true -> raise MoveError, message: "Move results in your king threatened with check: invalid"
    end
  end

  def newBoardPutsYouInCheck(new_board, playerColor) do
    Chessboard.kingThreatened(new_board, playerColor)
  end

  @doc """
  Provides additional checking for helping piecetype perform a move on a board, checks for
  more piece and move specific information, and eventually calls the function that performs
  the moves on the placements
  """
  def helpMove(:king, board, start_loc, end_loc, playerColor, _end_loc_placement, moveType, _impalable_loc, _promote_type, castleable_dirs) when moveType == :longcastle or moveType == :shortcastle do
    placements = board.placements
    #castling move
    unless castleNotSpent(moveType, castleable_dirs) do
      {:error, "castle has been spent, but trying to castle"}
    else
      unless kingCheckDoesntDisruptCastle(moveType, board, playerColor) do
        {:error, "The king is in check, disrupting this castle attempt"}
      else
        rook_spot = rookspot(playerColor, moveType)

        unless rookspotContainsRookForCastle(playerColor, placements, rook_spot) do
          {:error, "rookspot does not contain rook, which is needed for a castle"}
        else
          that_rook = get_at(placements, rook_spot)
          if piecesBetweenRookAndKingForCastle(placements, start_loc, rook_spot) do
            {:error, "there are pieces between the rook and king, so no castle"}
          else
            travel_spot = castle_travel_spot(start_loc, end_loc)
            if kingPassingThroughCheckForCastle(moveType, board, playerColor, travel_spot) do
              {:error, "king passing through check for castle"}
            else
              castlingMove(placements, start_loc, end_loc, {playerColor, :king}, rook_spot, travel_spot, that_rook)
            end
          end
        end
      end
    end
  end

  def helpMove(:king, board, start_loc, end_loc, playerColor, _end_loc_placement, _moveType, _impalable_loc, _promote_type, _castle) do
    # not castling, king move
    typicalMove(board.placements, start_loc, end_loc, {playerColor, :king})
  end

  def helpMove(:knight, board, start_loc, end_loc, playerColor, _end_loc_placement, _moveType, _impalable_loc, _promote_type, _castle) do
    # knight move
    typicalMove(board.placements, start_loc, end_loc, {playerColor, :knight})
  end

  def helpMove(:pawn, board, start_loc, end_loc, player_color, _end_loc_placement, moveType, impalable_loc, _promote_type, _castle) when moveType == :capture and impalable_loc == end_loc and impalable_loc != :noimpale do
    placements = board.placements
    # pawn, impaling
    # ignore passivity because it is a capture on empty space affecting the pawn behind the empty space
    unless impalingCaptureInFrontOfEnemyPawn(moveType, impalable_loc, placements, end_loc, player_color) do
      {:error, "the impaling capture is not in front of an enemy pawn?? something is amiss in the previous move"}
    else
      # if behind_at(placements, end_loc, player_color) != {:pawn, otherColor(player_color)} do
      #   {:error, "strange, the contents of the loc behind the impale square should be an enemy pawn, they are not"}
      # else
      pawn_behind_loc = behind(end_loc, player_color)
      # impale AKA enpassant
      # perform impale, with side effect of pawn behind where you're going being removed
      impalingMove(placements, start_loc, end_loc, {player_color, :pawn}, pawn_behind_loc)
      # end
    end
  end

  def helpMove(:pawn, board, start_loc, end_loc, player_color, end_loc_placement, moveType, _impalable_loc, promote_type, _castle) when moveType == :promote or moveType == :promotecapture do
    placements = board.placements
    # pawn promoting
    unless passivityMatchesResult(moveType, end_loc_placement) do
      {:error, "passivity does not match result"}
    else
      promotingMove(placements, start_loc, end_loc, {player_color, :pawn}, promote_type)
    end
  end

  def helpMove(:pawn, board, start_loc, end_loc, player_color, end_loc_placement, moveType, _impalable_loc, _promote_type, _castle) when moveType == :promote or moveType == :promotecapture do
    placements = board.placements
    # pawn, not promoting, not impaling
    unless passivityMatchesResult(moveType, end_loc_placement) do
      {:error, "passivity does not match result"}
    else
      typicalMove(placements, start_loc, end_loc, {player_color, :pawn})
    end
  end

  # bishop, rook, queen, not (king, pawn, knight)
  def helpMove(piece_type, board, start_loc, end_loc, player_color, _end_loc_placement, moveType, _impalable_loc, _promote_type, _castle) do
    placements = board.placements
    if rushingMovesHavePiecesInBetween(moveType, placements, end_loc, start_loc) do
      {:error, "rushing move has pieces in between"}
    else
      typicalMove(placements, start_loc, end_loc, {player_color, piece_type})
    end
  end

  ############################################

  def helpMove!(:king, board, start_loc, end_loc, playerColor, _end_loc_placement, moveType, _impalable_loc, _promote_type, castleable_dirs) when moveType == :longcastle or moveType == :shortcastle do
    placements = board.placements
    # a castling move
    ensureCastleNotSpent(moveType, castleable_dirs)
    ensureKingCheckDoesntDisruptCastle(moveType, board, playerColor)

    rook_spot = rookspot(playerColor, moveType)

    ensureRookspotContainsRookForCastle(playerColor, placements, rook_spot)

    that_rook = get_at(placements, rook_spot)

    ensureNoPiecesBetweenRookAndKingForCastle(placements, start_loc, rook_spot)

    travel_spot = castle_travel_spot(start_loc, end_loc)

    ensureKingNotPassingThroughCheckForCastle(moveType, placements, playerColor, travel_spot)

    castlingMove(placements, start_loc, end_loc, {playerColor, :king}, rook_spot, travel_spot, that_rook)
  end

  def helpMove!(:king, board, start_loc, end_loc, playerColor, _end_loc_placement, _moveType, _impalable_loc, _promote_type, _castle) do
    # ensureKingNotMovingIntoCheck
    typicalMove(board.placements, start_loc, end_loc, {playerColor, :king})
  end

  def helpMove!(:knight, board, start_loc, end_loc, playerColor, _end_loc_placement, _moveType, _impalable_loc, _promote_type, _castle) do
    typicalMove(board.placements, start_loc, end_loc, {playerColor, :knight})
  end

  def helpMove!(:pawn, board, start_loc, end_loc, player_color, _end_loc_placement, moveType, impalable_loc, _promote_type, _castle) when moveType == :capture and impalable_loc == end_loc and impalable_loc != :noimpale do
    placements = board.placements
    # impaling
    # ignore passivity because it is a capture on empty space affecting the pawn behind the empty space
    ensureImpalingCaptureInFrontOfEnemyPawn(moveType, impalable_loc, placements, end_loc, player_color)

    case behind_at(placements, end_loc, player_color) do
      :mt -> true
      _any ->
        raise ArgumentError, message: "strange, the contents should be mt"
    end
    pawn_behind_loc = behind(end_loc, player_color)

      # impale AKA enpassant
    # perform impale, with side effect of pawn behind where you're going being removed
    impalingMove(placements, start_loc, end_loc, {:pawn, player_color}, pawn_behind_loc)
  end

  def helpMove!(:pawn, placements, start_loc, end_loc, player_color, end_loc_placement, moveType, _impalable_loc, promote_type, _castle) when moveType == :promote or moveType == :promotecapture do
    # promoting
    #promoting = promote_type != :nopromote
    # already did in move fn but hey
    #ensurePromoteTypeValid(promote_type, moveType)
    ensurePassivityMatchesResult(moveType, end_loc_placement)

    promotingMove(placements, start_loc, end_loc, {:pawn, player_color}, promote_type)
  end

  def helpMove!(:pawn, placements, start_loc, end_loc, player_color, end_loc_placement, moveType, _impalable_loc, _promote_type, _castle) when moveType == :promote or moveType == :promotecapture do
    # not promoting, not impaling
    ensurePassivityMatchesResult(moveType, end_loc_placement)

    typicalMove(placements, start_loc, end_loc, {player_color, :pawn})
  end

  # bishop, rook, queen, not (king, pawn, knight)
  def helpMove!(piece_type, placements, start_loc, end_loc, player_color, _end_loc_placement, moveType, _impalable_loc, _promote_type, _castle) do
    ensureRushingMovesHavePiecesInBetween(moveType, placements, end_loc, start_loc)

    typicalMove(placements, start_loc, end_loc, {player_color, piece_type})
  end

  @doc """
  given a start loc, end loc, piece to move, and placements,
  performs a typical move, replacing the start_loc placement with :mt
  and replacing the end_loc with the moving_piece
  """
  def typicalMove(placements, start_loc, end_loc, moving_piece) do
    placements
    |> remove_at(start_loc)
    |> replace_at(end_loc, moving_piece)
  end

  @doc """
  given a start loc, end loc, piece to move, and placements,
  as well as a rook_spot, travel_spot (where rook will end up) and that_rook placement,
  performs a castling move, replacing the start_loc placement with :mt
  and replacing the end_loc with the moving_piece, and doing the same with
  """
  def castlingMove(placements, start_loc, end_loc, moving_piece, rook_spot, travel_spot, that_rook) do
    placements
    |> typicalMove(start_loc, end_loc, moving_piece)
    |> typicalMove(rook_spot, travel_spot, that_rook)
  end

  @doc """
  """
  def impalingMove(placements, start_loc, end_loc, moving_piece, pawn_behind_loc) do
    placements
    |> remove_at(start_loc)
    |> replace_at(end_loc, moving_piece)
    |> remove_at(pawn_behind_loc)
  end

  def promotingMove(placements, start_loc, end_loc, {color, :pawn} = _moving_piece, promote_type) do
    placements
    |> replace_at(start_loc, :mt)
    |> replace_at(end_loc, {color, promote_type})
  end

  @doc """
  Given a color, an order (list of two ordered colors) and the castleable directions for each color in order,
  returns the castleable directions for the the color
  """
  def grabCastleable(color, first_castleable, second_castleable, [first, second]) do
    case color do
      ^first -> first_castleable
      ^second -> second_castleable
    end
  end


  @doc """
  returns a tuple {ok: placements} containing the placements of the completed move
  or an error tuple {error: reason} if the move is invalid
  """
  def move(board, start_loc, end_loc, playerColor, pieceType, promote_type \\ :nopromote) do
    placements = board.placements
    _castleable_directions = grabCastleable(playerColor, board.first_castleable, board.second_castleable, board.order)
    _impalable_loc = board.impale_square
    moving_piece = get_at(placements, start_loc)

    unless placementNotEmpty(moving_piece) do
      {:error, "start location is empty, cannot move empty"}
    else
      unless placementAgreesWithProvidedInfo(moving_piece, playerColor, pieceType) do
        {:error, "start location has a different color or piecetype than indicated"}
      else
        end_loc_placement = get_at(placements, end_loc)
        ## they call my moving bool, 'passive' in some other chess engines,
        ## taking is then labeled 'active'
        case pieceType do
          :pawn -> pawn_move_take_validation(board, start_loc, end_loc, playerColor, moving_piece, end_loc_placement, promote_type)
          _other -> normal_validation(board, start_loc, end_loc, pieceType, playerColor, moving_piece, end_loc_placement)
        end
      end
    end
  end

  @doc """
  Given a board, start_loc, end_loc, playerColor, moving_piece, end_loc_placement, promote_type,
  validate a pawn move
  """
  def pawn_move_take_validation(board, start_loc, end_loc, playerColor, moving_piece, end_loc_placement, promote_type) do
    if end_loc_placement == :mt do
      # moving
      cond do
        diagonalMove(start_loc, end_loc) and in_front_of_enemy_pawn(board.placements, end_loc, playerColor) and board.impale_square == end_loc ->
          # this is an impaling move (en passant)
          commence_move(board, start_loc, end_loc, playerColor, :pawn, promote_type, moving_piece, end_loc_placement)

        diagonalMove(start_loc, end_loc) ->
          {:error, "attempting to move a pawn diagonally, a direction you can only take"}

        true ->
          commence_move(board, start_loc, end_loc, playerColor, :pawn, promote_type, moving_piece, end_loc_placement)
      end
    else
      # taking
      unless notTakingOwnPiece(end_loc_placement, playerColor) do
        {:error, "attempting to take own piece"}
      else
        if verticalMove(start_loc, end_loc) do
          {:error, "attempting to take vertically, a direction you can only move"}
        else
          commence_move(board, start_loc, end_loc, playerColor, :pawn, promote_type, moving_piece, end_loc_placement)
        end
      end
    end
  end

  def diagonalMove({s_col, s_row}, {e_col, e_row}) when s_col |> is_atom and e_col |> is_atom do
    diagonalMove({s_col |> column_to_int(), s_row}, {e_col |> column_to_int(), e_row})
  end

  def diagonalMove({s_col, s_row}, {e_col, e_row}) do
    abs(s_row - e_row) == 1 and abs(s_col - e_col) == 1
  end

  def verticalMove({s_col, s_row}, {e_col, e_row}) when s_col |> is_atom and e_col |> is_atom do
    verticalMove({s_col |> column_to_int(), s_row}, {e_col |> column_to_int(), e_row})
  end

  def verticalMove({s_col, s_row}, {e_col, e_row}) do
    s_col == e_col and abs(s_row - e_row) == 1 or abs(s_row - e_row) == 2
  end

  def normal_validation(board, start_loc, end_loc, pieceType, playerColor, moving_piece, end_loc_placement) do
    if end_loc_placement != :mt do
      unless notTakingOwnPiece(end_loc_placement, playerColor) do
        {:error, "attempting to take own piece"}
      else
        commence_move(board, start_loc, end_loc, playerColor, pieceType, :nopromote, moving_piece, end_loc_placement)
      end
    else
      commence_move(board, start_loc, end_loc, playerColor, pieceType, :nopromote, moving_piece, end_loc_placement)
    end
  end

  def commence_move(board, start_loc, end_loc, playerColor, pieceType, promote_type, _moving_piece, end_loc_placement) do
    placements = board.placements
    castleable_directions = grabCastleable(playerColor, board.first_castleable, board.second_castleable, board.order)
    impalable_loc = board.impale_square

    moveType = Moves.retrieveMoveType(start_loc, end_loc, pieceType, playerColor)

    unless moveTypeValid(moveType) do
      {:error, "invalid movetype"}
    else

    # so we know that just based on locations as well as color and type of the piece, we have plausible moves
    # Now we compare the conditions of the board with what movetype we're doing,
    if rushingMovesHavePiecesInBetween(moveType, placements, end_loc, start_loc) do
      {:error, "rushing move has a piece blocking where you're trying to go"}
    else
      unless promoteTypeValid(promote_type, moveType) do
        {:error, "promote type is invalid"}
      else
        case helpMove(pieceType, board, start_loc, end_loc, playerColor, end_loc_placement, moveType, impalable_loc, promote_type, castleable_directions) do
          {:error, msg} -> {:error, msg}
          result ->
            new_board = %{board | placements: result}
            if newBoardPutsYouInCheck(new_board, playerColor) do
              {:error, "new Board puts you in check, so you can't make this move"}
            else
              # also stuff about adjusting board metadata for moveType
              new_placements = new_board.placements

              # adjust impale_square
              impale_eval = case moveType do
                :sprint ->
                  # IO.inspect("#{inspect start_loc} <> #{inspect end_loc} <> #{inspect moveType}", label: :cool)
                  %{board | impale_square: behind(end_loc, playerColor)}
                _any -> %{board | impale_square: :noimpale}
              end

              # adjust castleable for the right playerColor
              castle_eval = cond do
                castleable_directions == :neither ->
                  impale_eval
                pieceType == :king and playerColor == :orange ->
                  %{impale_eval | first_castleable: :neither}
                pieceType == :king and playerColor == :blue ->
                  %{impale_eval | second_castleable: :neither}
                pieceType == :rook and long_rookspot(playerColor) == start_loc ->
                  Map.put(impale_eval, whichCastleable(playerColor), removeOption(castleable_directions, :longcastle))
                pieceType == :rook and short_rookspot(playerColor) == start_loc ->
                  Map.put(impale_eval, whichCastleable(playerColor), removeOption(castleable_directions, :shortcastle))
                true ->
                  impale_eval
              end

              # adjust half-move clock,
              #    reset if capture or pawn move, or castle move, otherwise increment one
              halfmove_clock_eval = if isCastle(moveType) or pieceType == :pawn or isCapture(placements, end_loc) do
                %{castle_eval | halfmove_clock: 0}
              else
                %{castle_eval | halfmove_clock: castle_eval.halfmove_clock + 1}
              end

              # adjust fullmove number,
              fullmove_eval = case playerColor do
                :orange ->
                  halfmove_clock_eval
                :blue -> %{halfmove_clock_eval | fullmove_number: board.fullmove_number + 1}
              end

              {:ok, %{fullmove_eval | placements: new_placements}}
            end
        end
      end
    end
  end
  end
  # ignores en passant captures, otherwise works
  def isCapture(placements, end_loc) do
    case get_at(placements, end_loc) do
      {_color, _type} -> true
      :mt -> false
    end
  end

  def removeOption(:both, :shortcastle), do: :queenside
  def removeOption(:both, :longcastle), do: :kingside
  def removeOption(:queenside, :longcastle), do: :neither
  def removeOption(:queenside, :shortcastle), do: :queenside
  def removeOption(:kingside, :shortcastle), do: :neither
  def removeOption(:kingside, :longcastle), do: :kingside

  def whichCastleable(:orange), do: :first_castleable
  def whichCastleable(:blue), do: :second_castleable

  def isCastle(:longcastle), do: true
  def isCastle(:shortcastle), do: true
  def isCastle(_any), do: false

  # def move!(board, start_loc, end_loc, playerColor, pieceType, promote_type \\ :nopromote) do
  #   case move(board, start_loc, end_loc, playerColor, pieceType, promote_type) do
  #     {:ok, new_board} -> new_board
  #     {:error, message} -> raise MoveError, message: message
  #   end
  # end

  def try_move!(board, move) do
    board
  end

  def move!(board, start_loc, end_loc, playerColor, pieceType, promote_type \\ :nopromote) do
    placements = board.placements
    castleable_directions = grabCastleable(playerColor, board.first_castleable, board.second_castleable, board.order)
    impalable_loc = board.impale_square

    moving_piece = get_at(placements, start_loc)


    ensurePlacementNotEmpty(moving_piece)

    ensurePlacementAgreesWithProvidedInfo(moving_piece, playerColor, pieceType)

    end_loc_placement = get_at(placements, end_loc)

    ## they call my moving bool, 'passive' in some other chess engines,
    ## taking is then labeled 'active'
    moving = end_loc_placement == :mt
    taking = not moving

    taking and ensureNotTakingOwnPiece(end_loc_placement, playerColor)

    moveType = Moves.retrieveMoveType(start_loc, end_loc, pieceType, playerColor)

    ensureMoveTypeValid(moveType, start_loc, end_loc, playerColor, pieceType)

    # so we know that just based on locations as well as color and type of the piece, we have plausible moves
    # Now we compare the conditions of the board with what movetype we're doing,

    ensureRushingMovesHavePiecesInBetween(moveType, placements, end_loc, start_loc)

    ensurePromoteTypeValid(promote_type, moveType)

    # movetype_validator =
    # move_fn
    new_board = %{board | placements: helpMove!(pieceType, board, start_loc, end_loc, playerColor, end_loc_placement, moveType, impalable_loc, promote_type, castleable_directions)}

    ensureNewBoardDoesNotPutYouInCheck(new_board, playerColor)
    new_placements = new_board.placements

    %{board | placements: new_placements}
  end

  @doc """
  makes a move given two locations (start and end), as well as {player_color and piece_type} or
  if you do not provide those, the placement at start is moved
  """
  def move_no_checks(placements, start_loc, end_loc, player_color, piece_type) do
    placements
    |> replace_at(start_loc, :mt)
    |> replace_at(end_loc, {player_color, piece_type})
  end

  def move_no_checks(placements, start_loc, end_loc) do
    moving_piece = get_at(placements, start_loc)

    placements
    |> replace_at(start_loc, :mt)
    |> replace_at(end_loc, moving_piece)
  end

  @doc """
  create a board from a bunch of _initial_ piece placements
  reject placements that result in boards where: tiles are not in a 3x3 to 8x8 or anywhere in between
  (so 3x8 is valid), pawns are in their colors rankupzone, either king is in stalemate or checkmate
  """
  def createBoardInitial(list_of_placements) do
    Board.Utils.make2DList(8, 8)
    |> recCreateBoardInitial(list_of_placements)
  end

  @doc """
  Creates a board, ready to play chess on
  """
  def createBoard() do
    # %Chessboard{
    #   placements: startingPosition(),
    #   order: [@firstColor, @secondColor],
    #   impale_square: :noimpale,
    #   first_castleable: :both,
    #   second_castleable: :both,
    #   halfmove_clock: 0,
    #   fullmove_number: 1,
    # }
    # aka
    %Chessboard{
      placements: startingPosition()
    }
  end

  defp recCreateBoardInitial(board, []), do: board

  defp recCreateBoardInitial(brd, [{f_loc, pieceColor, pieceType}]) do
    brd
    |> placePiece(f_loc, pieceColor, pieceType)
  end

  defp recCreateBoardInitial(brd, [{f_loc, pieceColor, pieceType} | tail]) do
    brd
    |> placePiece(f_loc, pieceColor, pieceType)
    |> recCreateBoardInitial(tail)
  end

  @doc """
  creates a state from a bunch of intermediate player placements
  operation should _try to_ reject placements that result in boards with
  piece placements that couldn't have possibly resulted from a series of turns
  (ie pawn in the first row, two bishops on the same color and 8 pawns)
  """
  def createBoard(lop) do
    createBoardInitial(lop)
  end

  # might need other operations to design these, consider making public if there's
  # a need for players or refs (via rule checkers) to use them

  # the board cannot enforce rules. Baking some basic constraints into the boards'
  # presence is ok to do. Above methods give examples as to what those are

  @doc """
  Given placements and a line separator, print the placements to commandline
  as a chess board
  """
  def printPlacements(placements, line_sep \\ "\n") do
    placements
    |> Board.Utils.reverseRanks()
    #|> Enum.intersperse(:switch_tiles)
    |> Enum.map(fn
      x -> Board.Utils.printRank(:chess, x, "\t ") <> line_sep
      end) |> to_string() |> inspect()
    #Enum.intersperse()
    Tile.renderTile(:blue)
    Tile.renderTile(:orange)
    # we need nested tile colors to zip into the board
    Tile.nestedTileColors()
    # so we must zip TWICE (zip ranks, zip placements)
    |> Enum.zip_with(placements,
      fn (tile_color_rank, board_rank) ->
        Enum.zip_with(tile_color_rank, board_rank, fn
          tile_color, :mt -> tile_color
          _tile_color, not_empty -> not_empty
          end)
        end)
    ## |> Enum.map(fn x -> Enum.chunk_every(x, 2) |> List.to_tuple() end)
    |> Board.Utils.map_to_each(&Board.Utils.translate/1)
    |> Enum.reduce("", fn x, accum -> accum <> Enum.reduce(x, "", fn item, acc -> acc <> item end) end)
  end

  def printFEN(board) do
    placement_str = printPlacements(board.placements, "")
    other = "other"
    placement_str <> other
  end

  def  blue_or_orange(true) do
    false
  end

  def listPlacements(placements) do
    #Board.Utils.nested_convert_to_formal(placements) |>
    placements
    |> Board.Utils.reverseRanks()
    |> Enum.map(fn
      x -> Enum.map(x, fn
        y -> Board.Utils.translate(y) end) end)
  end

  @doc """
  Returns true when the game is over by board-conditions
   (checkmate, stalemate, or insufficient material)
  """
  def isOver(board, to_play) do
    isFiftyMoveRepitition(board, to_play) or
    isCheckmate(board, to_play) or
    isStalemate(board, to_play) or
    isInsufficientMaterial(board)
  end

  def isFiftyMoveRepitition(board, _to_play) do
    board.halfmove_clock == 50
  end

  @doc """
  Returns true when, (playing as the color indicated by to_play)
  the player is in checkmate
  """
  def isCheckmate(board, to_play) do
    isCheck(board, to_play) and # done
    kingImmobile(board, to_play) # done
    and noMovesResolvingCheck(board, to_play) # todo
  end

  @doc """
  Returns true when, (playing as the color indicated by to_play)
  the player is in stalemate
  """
  def isStalemate(board, to_play) do
    _placements = board.placements
    #   Complete (check)             todo                              todo                                    todo
    kingImmobile(board, to_play) and
    not isCheck(board, to_play) and
    noPieceCanMove(board, to_play)
  end

  @doc """
  Returns true when the king is being threatened by the opposing player's pieces
  """
  def isCheck(board, to_play) when board |> is_struct() do
    threatening_moves = threatens(board, otherColor(to_play))
    threatened = threatening_moves |> Enum.map(&move_to_end_loc/1)
    king_loc = findKing(board.placements, to_play)
    Enum.member?(threatened, king_loc)
  end

  def move_to_end_loc({_start_loc, end_loc}), do: end_loc

  @doc """
  Returns true if no king move will escape check
  """
  def kingImmobile(board, color) when board |> is_struct() do
    placements = board.placements
    king_loc = findKing(placements, color)
    my_unappraised_king_moves = possible_moves(board, king_loc, color)
    my_real_king_moves = my_unappraised_king_moves
    |> Enum.map(fn {_movetype, end_loc} ->
      appraise_move(board, king_loc, end_loc, {color, :king})
    end)
    |> Enum.reject(fn
      {:error, _message} -> true
      {:ok, _board_struct} -> false
    end)
    |> Enum.map(fn {:ok, board_struct} -> board_struct end)
    # no possible moves
    my_real_king_moves |> length() == 0

    # so there's generated possible moves, wh
  end

  @doc """
  Reduces a function to each location on the placements of the board, returns a list,
  with the function reduced onto each location.
  """
  def reduce_placements(placements, acc, fun) do
    Enum.map(placements, fn rank -> Enum.map(rank, fn tile -> fun.(tile, acc) end) end)
  end

  def transform_list_loc_placement_tuple_to_tuple_piecetype_list_possible_moves(list_loc_placement_tuple, board, to_play) do
    list_loc_placement_tuple
    |> Enum.map(fn
      {loc, {^to_play, piece_type}} ->
        {piece_type, possible_moves(board, loc, to_play)}
    end)
  end

  @doc """
  Given a list of tuples of {piecetype, possible_move_list} a board, and the color of the player whose turn it is,
  return a list of all of the possible moves FOR ALL tuples IN THE LIST
  """
  def perform_list_possible_moves(list_tuple_piecetype_list_possible_moves, board, to_play) do
    list_tuple_piecetype_list_possible_moves
    |> Enum.map(fn
      [] -> []
      {piece_type, [{start_loc, end_loc}]} when start_loc |> is_tuple() and end_loc |> is_tuple() ->
        move(board, start_loc, end_loc, to_play, piece_type, :nopromote)
      {piece_type, list_moves} when list_moves |> is_list() and length(list_moves) > 1 ->
        list_moves
        |> Enum.map(fn
          {start_loc, end_loc, promote_to} ->
            move(board, start_loc, end_loc, to_play, piece_type, promote_to)
          {start_loc, end_loc} ->
            move(board, start_loc, end_loc, to_play, piece_type, :nopromote)
        end)
      {piece_type, []} when piece_type |> is_atom() ->
        []
    end)
    |> List.flatten()
  end


  @doc """
  given a board and a color, returns true if there are no possible
  moves by pieces of that color that would resolve check
  (if you're not in check, this is not a useful fn :) )
  """
  def noMovesResolvingCheck(board, to_play) when board |> is_struct() do
    threatening_moves = threatens(board, otherColor(to_play))
    threatened = threatening_moves |> Enum.map(&move_to_end_loc/1)
    king_loc = findKing(board.placements, to_play)
    king_moves = possible_moves(board, king_loc, to_play)
    # in the format [ {loc, placement} ...]
    all_friendly_pieces = fetch_locations(board.placements, to_play)

    # we want to change the : list of {loc, placement} to : list of possible_moves,
    # then go through them, apply them onto the board,
    # and call isCheck on the new_board for to_play,
    # then, reduce the list of booleans to one result with Enum.all?()
    # so if one is not check, then there is a move resolving check, so false

    all_friendly_pieces_moves = all_friendly_pieces
    |> transform_list_loc_placement_tuple_to_tuple_piecetype_list_possible_moves(board, to_play)
    |> perform_list_possible_moves(board, to_play)



    Enum.all?(king_moves, fn move -> Enum.member?(threatened, move) end) and
    all_friendly_pieces_moves == []
  end

  @doc """
  Given placements and a color (to_play) returns a bool representing
  Whether ANY piece in that color can play a move
  """
  def noPieceCanMove(board, to_play) do
    board |> possible_moves_of_color(to_play) |> length() == 0
  end

  @doc """
  Given a placements and a location, returns whether that piece can move nowhere
  """
  def immobile(placements, loc) do
    possible_moves(placements, loc) |> length() == 0
    # check for stuff extra?
  end

  @doc """
  Given a board, a start_loc, end_loc, and a placement (should match the start_loc),
  appraise the move. That is, try and make the move and see if it succeeds,
  returns a result tuple, with {:ok, new_board} if it's ok, and {:error, message}
  if it failed
  """
  def appraise_move(board, start_loc, end_loc, {color, piece_type}) do
    # probably should insert logic here to deal with promotion, but good for now
    tuple = move(board, start_loc, end_loc, color, piece_type)
    case tuple do
      {:ok, _new_board} -> tuple
      {:error, _message} -> tuple
    end
  end

  def appraise_move(board, start_loc, end_loc, {color, piece_type}, promote_to) do
    # probably should insert logic here to deal with promotion, but good for now
    tuple = move(board, start_loc, end_loc, color, piece_type, promote_to)

    case tuple do
      {:ok, _new_board} -> tuple
      {:error, _message} -> tuple
    end
  end

  # @doc """
  # returns a list of all moves that a specific placement can make (a piece and color at a certain location)
  # """
  # def possible_moves(board, color) when color |> is_atom() and placements |> is_list() do
  #   Chessboard.fetch_locations(placements, color)
  #   |> Enum.map(fn {loc, {^color, type} = placement} = x ->
  #     Moves.unappraised_moves(color, type, loc)
  #     |> Enum.map(fn
  #       {move_type, {promote_to, end_loc}} when end_loc |> is_tuple() ->
  #         {end_loc, appraise_move(board, loc, end_loc, placement, promote_to), promote_to}
  #       {move_type, {promote_to, :ob}} ->
  #         {{0,0}, {:error, :ob}}
  #       {move_type, end_loc} when end_loc |> is_tuple() ->
  #         {end_loc, appraise_move(board, loc, end_loc, placement)}
  #       end)
  #     |> Enum.filter(fn
  #       {_end_loc, {:ok, _new_board}} -> true
  #       {_end_loc, {:error, _message}} -> false
  #       {_end_loc, {:ok, _new_board}, _promote_to} -> true
  #       {_end_loc, {:error, _message}, _promote_to} -> false
  #     end)
  #     |> Enum.map(fn
  #       {end_loc, {:ok, board}} -> {loc, end_loc}
  #       {end_loc, {:ok, n_board}, promote_to} -> {loc, end_loc, promote_to}
  #     end)
  #   end)
  #   |> List.flatten()
  # end

  @doc """
  Given a list of moves (tuple of two locs), a board, a placement, a loc and color,
  Evaluate each
  """
  def evaluate_each_unappraised(list_unappraised_moves, board, placement, loc, color) do
    list_unappraised_moves
    |> Enum.map(fn
      {mv_ty_promote, {{^color, _promote_to}, :ob}} when mv_ty_promote in [:capturepromote, :promote] ->
        {{0, 1}, {:error, :ob}}
      {mv_ty_promote, {{^color, promote_to}, end_loc}} when mv_ty_promote in [:capturepromote, :promote] ->
        {end_loc, appraise_move(board, loc, end_loc, placement, promote_to), promote_to}
      {_move_type, {_promote_to, :ob}} ->
        {{0, 0}, {:error, :ob}}
      {_move_type, {_e_col, e_row} = end_loc} when end_loc |> is_tuple() and e_row |> is_integer() ->
        {end_loc, appraise_move(board, loc, end_loc, placement)}
      any ->
        IO.puts(inspect(any))
        raise ArgumentError, message: inspect(any)
      end)
  end

  @doc """
  Given a board, a location, a color and a type, return the list of moves that are possible at that location,
  includes checking for king moves into check
  """
  def appraise_each_loc_placement_tuples_to_move_tuples_or_thruples(board, loc, color, type) do
    placement = {color, type}
    Moves.unappraised_moves(color, type, loc)
    |> evaluate_each_unappraised(board, placement, loc, color)
    |> Enum.filter(fn
      {_end_loc, {:ok, _new_board}} -> true
      {_end_loc, {:error, _message}} -> false
      {_end_loc, {:ok, _new_board}, _promote_to} -> true
      {_end_loc, {:error, _message}, _promote_to} -> false
    end)
    |> Enum.map(fn
      {end_loc, {:ok, _board}} -> {loc, end_loc}
      {end_loc, {:ok, _n_board}, promote_to} -> {loc, end_loc, promote_to}
    end)
  end

  @doc """
  Given a board and a player_color, return all possible moves of that color
  """
  def possible_moves_of_color(board, color) when color |> is_atom() and board |> is_struct() do
    Chessboard.fetch_locations(board.placements, color)
    |> Enum.map(fn {loc, {^color, type} = _placement} ->
      appraise_each_loc_placement_tuples_to_move_tuples_or_thruples(board, loc, color, type)
    end)
    |> List.flatten()
  end

  @doc """
  Given a board and a location, return a list of the possible moves from that location
  """
  def possible_moves(board, location) when board |> is_struct() and location |> is_tuple() and elem(location, 1) |> is_integer() do
    placements = board.placements

    case get_at(placements, location) do
      :mt -> []
      {piece_color, _pieceType} -> possible_moves(board, location, piece_color)
    end
  end

  def possible_moves(board, {_file, _rank} = loc, playerColor) when board |> is_struct()  and playerColor |> is_atom() do
    placements = board.placements
    {pieceColor, pieceType} = _current_placement = get_at(placements, loc)

    if pieceColor != playerColor do
      :opponent_piece

      raise BoardError, message: "pieceColor #{inspect(pieceColor)} and piecetype #{pieceType} at #{inspect(loc)} are not #{playerColor}"
      # raise ArgumentError, message: "pieceColor does not match the piece at the location"
    else
      appraise_each_loc_placement_tuples_to_move_tuples_or_thruples(board, loc, playerColor, pieceType)
    end
  end

  @doc """
  produces a nested approximation of the board_placements,
  with each location containing within it it's own location
  """
  def all_locations_nested(:dumb) do
    0..7 |> Enum.map(fn rank -> 0..7 |> Enum.map(fn file -> {rank, file} end) end)
  end

  def all_locations_nested(:formal) do
    8..1
    |> Enum.map(fn rank -> 1..8
    |> Enum.map(fn file -> {int_to_column(file), rank} end) end)
  end

  @doc """
  produces a list of all the locations on the board,
  in order from top left to bottom right
  """
  def all_locations_list(atom) when atom in [:dumb, :formal] do
    all_locations_nested(atom) |> List.flatten()
  end

  @doc """
  Looks in the placements and returns a list of tuples of {location, placement}
  for every piece on the placements (including :mt)
  """
  def fetch_locations(placements) when placements |> is_list() do
    all_locations_list(:formal)
    |> Enum.map(fn loc -> {loc, get_at(placements, Location.dumbLocation(loc))} end)
  end



  @doc """
  Looks in the placements and returns a list of all the locations of the specified playerColor, or
  of the specified playerColor and pieceType
  in format List of tuples of {location, placement}
  where placement is {color, type}
  """
  def fetch_locations(placements, playerColor) when placements |> is_list() do
    only_player_color_nested = placements
    |> reduce_placements([],
    fn
      {^playerColor, type}, acc -> acc ++ [{playerColor, type}]
      {_otherColor, _type}, acc -> acc
      :mt, acc -> acc
      other, acc -> raise ArgumentError, message: "invalid tile #{inspect(other)} with acc #{inspect(acc)}"
    end)

    all_locations_list(:formal)
    |> Enum.map(fn loc -> {loc, get_at(only_player_color_nested, Location.dumbLocation(loc))} end)
    |> Enum.reject(fn
      {_loc, []} -> true
      {_loc, _any} -> false end)
    |> Enum.map(fn
      {loc, list} when list |> is_list() -> {loc, List.first(list)}
    end)
  end

  def fetch_locations(placements, playerColor, pieceType) when placements |> is_list() do
    only_color_and_piecetype_nested = placements
    |> reduce_placements([], fn
      {^playerColor, ^pieceType}, acc -> acc ++ [{playerColor, pieceType}]
      {_otherColor, _type}, acc -> acc
      :mt, acc -> acc
      other, acc -> raise ArgumentError, message: "invalid tile #{inspect(other)} with acc #{inspect(acc)}"
    end)

    all_locations_list(:formal)
    |> Enum.map(fn loc -> {loc, get_at(only_color_and_piecetype_nested, Location.dumbLocation(loc))} end)
    |> Enum.reject(fn
      {_loc, []} -> true
      {_loc, _any} -> false end)
    |> Enum.map(fn {loc, list} when list |> is_list() -> {loc, List.first(list)}
    end)
  end


    # we want the raw moves assuming every possible move of a piece is valid, so for pawns, always sprinting, all directions of horse etc
    # moves_strategy(board, pieceColor, location, false, pawn_moves/2)
    # filter out impossible moves (off the board, or causes check, or is blocked by a piece, or is capturing a friendly piece)
    # |> Enum.filter(fn () ->  end)
    # convert each possible remaining move to a convenient move format (?) (ie {start, end} or {start, end, pieceType}) ?
    #|> Enum.map(fn () ->  end)

    @doc """
    returns whether there are any pieces standing between these two locations
    (that are not at those locations), returns false if the locations are not on
    the same rank, file, or diagonal
    """
  def blocked(placements, {atomic_start_file, start_rank} = s_loc, {atomic_end_file, end_rank} = e_loc) do
    start_file = column_to_int(atomic_start_file)
    end_file = column_to_int(atomic_end_file)
    in_the_way = cond do
      start_rank == end_rank ->
        pieces_between(placements, end_rank, {start_file, end_file})
      start_file == end_file ->
        pieces_between(placements, {start_rank, end_rank}, end_file)
      on_diagonal?(start_file, start_rank, end_file, end_rank) ->
        pieces_between(placements, {start_file, start_rank}, {end_file, end_rank})
      true ->
        :not_visible
        #raise ArgumentError, message: "hmm #{inspect(:not_visible)}"
    end
    # in the way will include the actual pieces? noooo
    trimmed = case in_the_way do
      list when list |> is_list() -> list |> removeLocations([s_loc, e_loc])
      :not_visible -> :not_visible
    end
    [] != trimmed
  end

  def removeLocations(in_the_way_list_tuples, list_locations) do
    in_the_way_list_tuples
    |> Enum.reject(fn
      {loc, _placement} -> loc in list_locations
      _any -> false
    end)
  end


  @doc """
  returns whether the two locations are on the same diagonal (uses math slope knowledge)
  """
  def on_diagonal?(x1, y1, x2, y2), do: y2 - y1 == x2 - x1 or y2 - y1 == x1 - x2

  #### GENERAL DIRECTION FUNCTIONS #### AND THEIR RECURSIVE HELPERS

  @doc """
  trawls the board and returns a list of all the pieces between the two locations,
  BUT the start and end locations do NOT count as pieces between
  """
  def up(board, y1, y2, x) do #5 7 1
    yn = y1 + 1
    case yn do
      ^y2 -> []
      _ -> recUp(board, yn, y2, x, [])
    end
  end

  def down(board, y1, y2, x) do # 7 5 1
    up(board, y2, y1, x) # 5 7 1
  end

  def recUp(board, start_rank, end_rank, x, acc) do
    # 6 7 1
    placement = get_at(board, {int_to_column(x), start_rank})

    new_acc = case placement do
      :mt -> acc
      {color, type} -> acc ++ [{{start_rank, x}, {color, type}}]
    end

    new_rank = start_rank + 1

    case new_rank do
      ^end_rank -> new_acc
      _ -> recUp(board, new_rank, end_rank, x, new_acc)
    end
  end

  def right(board, y, x1, x2) do
    xn = x1 + 1
    case xn do
      ^x2 -> []
      _ -> recRight(board, y, x1, x2, [])
    end
  end

  def left(board, y, x1, x2) do
    right(board, y, x2, x1)
  end

  def recRight(board, y, start_file, end_file, acc) do
    placement = get_at(board, {int_to_column(start_file), y})

    new_acc = case placement do
      :mt -> acc
      {color, type} -> acc ++ [{{int_to_column(start_file), y}, {color, type}}]
    end

    new_file = start_file + 1

    case new_file do
      ^end_file -> new_acc
      _ -> recRight(board, y, new_file, end_file, new_acc)
    end
  end

  def upRight(board, y1, x1, y2, x2) do
    xn = x1 + 1
    yn = y1 + 1
    case {xn, yn} do
      {^x2, ^y2} -> []
      _ -> recUpRight(board, y1, x1, y2, x2, [])
    end
  end

  def downLeft(board, y1, x1, y2, x2) do
    upRight(board, y2, x2, y1, x1)
  end

  def upLeft(board, y1, x1, y2, x2) do
    xn = x1 - 1
    yn = y1 + 1
    case {xn, yn} do
      {^x2, ^y2} -> []
      _ -> recUpLeft(board, y1, x1, y2, x2, [])
    end
  end

  def downRight(board, y1, x1, y2, x2) do
    upLeft(board, y2, x2, y1, x1)
  end

  def recUpLeft(board, start_rank, start_file, end_rank, end_file, acc) do
    placement = get_at(board, {int_to_column(start_file), start_rank})

    new_acc = case placement do
      :mt -> acc
      {color, type} -> acc ++ [{{int_to_column(start_file), start_rank}, {color, type}}]
    end

    new_file = start_file - 1
    new_rank = start_rank + 1

    case {new_file, new_rank} do
      {^end_file, ^end_rank} -> new_acc
      _ -> recUpLeft(board, new_rank, new_file, end_rank, end_file, new_acc)
    end
  end

  def recUpRight(board, start_rank, start_file, end_rank, end_file, acc) do
    placement = get_at(board, {int_to_column(start_file), start_rank})

    new_acc = case placement do
      :mt -> acc
      {color, type} -> acc ++ [{{int_to_column(start_file), start_rank}, {color, type}}]
    end

    new_file = start_file + 1
    new_rank = start_rank + 1

    case {new_file, new_rank} do
      {^end_file, ^end_rank} -> new_acc # change this so it doesn't include the piece at the loc
      _ -> recUpRight(board, new_rank, new_file, end_rank, end_file, new_acc)
    end
  end

  @doc """
  returns a list of {location, placement} which represent pieces between the two locations
  """
  def pieces_between(board, {start_file, start_rank}, {end_file, end_rank}) do
    cond do # file = x, rank = y
      start_rank > end_rank and start_file < end_file -> # negative slope (down right)
        downRight(board, start_rank, start_file, end_rank, end_file)
      start_rank > end_rank and start_file > end_file -> # positive slope (down left)
        downLeft(board, start_rank, start_file, end_rank, end_file)
      start_rank < end_rank and start_file > end_file -> # positive slope (up left)
        upLeft(board, start_rank, start_file, end_rank, end_file)
      start_rank < end_rank and start_file < end_file -> # negative slope (up right)
        upRight(board, start_rank, start_file, end_rank, end_file)
      true ->
        "one_or_more_is_equal"
    end
  end

  def pieces_between(board, rank, {start_file, end_file}) do
    cond do # file = x, rank = y (same rank)
      start_file < end_file -> # head right
        right(board, rank, start_file, end_file)
      start_file > end_file -> # head left
        left(board, rank, start_file, end_file)
      true -> "file_also_equal"
    end
  end

  def pieces_between(board, {start_rank, end_rank}, file) do
    cond do # file = x, rank = y (same file)
      start_rank < end_rank -> # head up
        up(board, start_rank, end_rank, file)
      start_rank > end_rank -> # head down
        down(board, start_rank, end_rank, file)
      true -> "rank_also_equal"
    end
  end

  def filter_location_placement_tuples_for_color(list_loc_pla_tuples, color) do
    list_loc_pla_tuples
        # now we traverse it
        |> Enum.map(fn
          # the ^ symbol indicates it's pattern matching on existing color
          {{_col, _row} = loc, {^color, p_type}} ->
              # piece color is as specified
              {loc, {color, p_type}}
          {{_col, _row} = loc, {_other_color, _p_type}} ->
            # any other color than the one specified
            {loc, :opposing_piece}
          {{_col, _row} = loc, :mt} ->
            {loc, :mt}
          end)
          |> Enum.reject(fn
            {_, :opposing_piece} -> true
            {_, :mt} -> true
            _ -> false
          end)
  end

  def grab_possible_moves(list_loc_pla_tuples, board) do
    list_loc_pla_tuples
    |> Enum.map(fn
      # the ^ symbol indicates it's pattern matching on existing color
      {{_col, _row} = loc, {color, _p_type}} ->
          # piece color is as specified
          possible_moves(board, loc, color)
      end)
  end

  def infer_move_type_from_board(list_o_list_o_possmoves, board) do
    list_o_list_o_possmoves
    ## so above we have a list tuples:
    #     {starting_location, list_of_movetype_ending_location_tuples}
    #     which look like [{move_type, ending_location},..]
    #where plausible moves are moves that are not obviously ending up off the board
    # or requiring a specific starting position (like sprinting, enpassant, castling, etc)
    # now lets put that start_location in the actual tuple
    |> Enum.map(fn plausible_loc_list when plausible_loc_list |> is_list() ->
        Enum.map(plausible_loc_list, fn
          {start_loc, end_loc, _promote_to} ->
            {Moves.infer_move_type(board, start_loc, end_loc), start_loc, end_loc}
          {start_loc, end_loc} ->
            {Moves.infer_move_type(board, start_loc, end_loc), start_loc, end_loc}
        end)
    end)
    |> List.flatten
    ## so we put the start_loc in every interior tuple, outer tuple gotten rid of
      # now we have a list of tuples in the form:
      #     {move_type, start_loc, end_loc}
  end

  def throw_out_ob_and_remove_promote_type_and_filter_out_blocked(list_thruples_moves, placements) do
    list_thruples_moves
    |> Enum.map(fn
      {_move_type, _start_loc, {_promote_to, :ob}} -> :ob
      {move_type, start_loc, end_loc} ->
      # at every plausible movetype with an end_location ...
      # if the move is blocked, then we don't want to include it
      # if the move is not blocked, then we want to include it

        real_end_loc = case end_loc do
          {col, row} when is_atom(col) -> {col, row}
          {_promote_type, {col, row}} ->
            {col, row}
        end

        block_bool = blocked(placements, start_loc, real_end_loc)

        cond do
          Moves.jumping(move_type) -> {move_type, start_loc, end_loc}
          block_bool -> :blocked
          not block_bool -> {move_type, start_loc, end_loc}
        end
    end)
    # remove the :blocked
    |> Enum.reject(fn
      :blocked -> true
      :ob -> true
      _ -> false
    end)
  end

  def remove_move_onlies(list_thruples) do
    # Now the above has a list of {move_type, start_loc, end_loc} tuples
    # we will remove the moves that are move_only (like sprinting, castling, etc)
    list_thruples
    |> Enum.reject(fn
      {move_type, _start_loc, _end_loc} ->
        Moves.moveOnly(move_type)
      _ -> false
      end)
  end

  def thruple_to_tuple_kill_movetype(list_thruples) do
    list_thruples
    ## Now we have all the logic we need, we'll get rid of the move_type to
    ## get a list of {start_loc, end_loc} tuples, PERFECT
    |> Enum.map(fn
      {_move_type, start_loc, end_loc} ->
        {start_loc, end_loc}
      end)
  end

  @doc """
  Produce a list of all locations that the color specifies threatens on the board
  I will need to reconcile whether or not this includes moves
  that are impossible because they would place the color king in check
  (unblocking a threat on the king). I think it should, because you can
  put an opposing king in check by blocking a threat on your own king.
  """
  def threatens(board, color) when board |> is_struct() and color |> is_atom() do
    placements = board.placements

    list_of_location_placement_tuples = Chessboard.fetch_locations(placements)
    |> filter_location_placement_tuples_for_color(color)
    |> grab_possible_moves(board)
    |> infer_move_type_from_board(board)
    |> throw_out_ob_and_remove_promote_type_and_filter_out_blocked(placements)
    |> remove_move_onlies()
    |> thruple_to_tuple_kill_movetype()
    |> Enum.uniq()

    list_of_location_placement_tuples
  end

  @doc """
  Goes through the board placements and finds the king of the color specified, returning it's location
  Always a tuple.
  """
  def findKing(placements, color) do
    for rank <- placements, tile <- rank do
      case tile do
        {pieceColor, pieceType} ->
          if pieceColor == color and pieceType == :king do
            {pieceColor, pieceType}
          else
            :not_king
          end
        :mt -> :mt
      end
    end
    |> Enum.zip(Chessboard.all_locations_list(:formal))
    |> Enum.reject(fn
      {:not_king, _loc} -> true
      {:mt, _loc} -> true
      {{^color, :king}, _loc} -> false
      end)
    |> raiseErrorIfEmpty(color)
    |> Enum.map(fn
      {{^color, :king}, loc} -> loc
      end)
    |> Enum.reduce(fn x, acc -> {x, acc} end)
  end

  def raiseErrorIfEmpty([], color) do
    raise BoardError, message: "there is no king of the specified color #{inspect(color)}"
  end
  def raiseErrorIfEmpty(list, _), do: list

  @doc """
  given placements and a color of the playing player,
  returns whether the possible moves for every piece are zero,
  if one piece has a move for exampole, it returns false
  """
  def noMoves(board, to_play) do
    for rank <- board, tile <- rank do
      {pieceColor, pieceType} = tile
      if pieceColor == to_play do
        # interesting, but we need no moves possible for any piece, so all piecetypes
        if not Enum.empty?(possible_moves(board, pieceType, tile)) do
          false
        end
      end
    end
    true
  end

  @doc """
  Given a board placements, reduces it to a list, with no location data
  """
  def listify(placements) do
    placements
    |> Enum.reduce([], fn x, accum -> accum ++ Enum.reduce(x, [], fn item, acc -> acc ++ [item] end) end)
  end

  @doc """
  Given a board, a piecetype and a color,
  reduces it to a list of only the color and piecetypes specified
  """
  def grab(placements, color, piecetype) do
    placements
    |> listify()
    |> Enum.filter(fn
      {^color, ^piecetype} -> true
      _other -> false
    end)
  end

  @doc """
  Given a board, a piecetype and a color,
  reduces it to a list of only the piecetypes specified
  """
  def grab(placements, piecetype) do
    placements
    |> listify()
    |> Enum.filter(fn
      {_col, ^piecetype} -> true
      _other -> false
    end)
  end

  @doc """
  Given a board and a color,
  reduces it to a list of only the pieces of that color
  """
  def grabColor(placements, color) do
    placements
    |> listify()
    |> Enum.filter(fn
      {^color, _piecetype} -> true

      _other -> false
    end)
  end

  @doc """
  The types of ways to hit insufficient material, and therefore a draw, are
  if both sides have one of the following and no pawns on the board

  - a lone king
  - a king and 1 bishop
  - a king and 1 knight

  and then (becuase king (bishop or knight) vs king knight knight is not a draw)
  - a king and two knights versus a lone king
  """
  def isInsufficientMaterial(board) do
    placements = board.placements
    cond do
      kingKnightKnight(placements, :orange) and justKing(placements, :blue) -> true
      kingKnightKnight(placements, :blue) and justKing(placements, :orange) -> true
      badMaterial(placements, :orange) and badMaterial(placements, :blue) -> true
      true -> false
    end
  end

  @doc """
  given placements and a color,
  returns whether that color only has the pieces, king and two knights
  """
  def kingKnightKnight(placements, color) do
    knight = grab(placements, color, :knight) |> length()
    king = grab(placements, color, :king) |> length()
    total = grabColor(placements, color) |> length()

    total == 3 and knight == 2 and king == 1
  end

  @doc """
  given placements and a color,
  returns whether that color only has a king
  """
  def justKing(placements, color) do
    king = grab(placements, color, :king) |> length()
    total = grabColor(placements, color) |> length()

    total == 1 and king == 1
  end

  @doc """
  given placements and a color,
  returns whether that color has just a king or
  just a king and a minor piece (bishop or knight)
  """
  def badMaterial(placements, color) do
    bishop = grab(placements, color, :bishop) |> length()
    knight = grab(placements, color, :knight) |> length()
    minor_pieces = bishop + knight
    king = grab(placements, color, :king) |> length()
    total = grabColor(placements, color) |> length()

    (total == 1 and king == 1) or (total == 2 and king == 1 and minor_pieces == 1)
  end

  @doc """
  Given a board and a color representing the turn, returns whether the current
  board is a draw or not
  """
  def isDraw(board, to_play) do
    isInsufficientMaterial(board) or isStalemate(board, to_play) or isThreeFoldRepitition(board, to_play) or isFiftyMoveRepitition(board, to_play)
  end

  def isThreeFoldRepitition(_board, _to_play) do
    #todo
    false
  end


  #########################################
  # CONVENIENCE FUNCTIONS
  #########################################

  @doc """
  creates a starting position, placing all tiles,
  then all starting pieces on the board
  """
  def startingPosition() do
    Board.Utils.make2DList(8, 8)
    # orange pawns
    |> placePiece({:a, 2}, :orange, :pawn)
    |> placePiece({:b, 2}, :orange, :pawn)
    |> placePiece({:c, 2}, :orange, :pawn)
    |> placePiece({:d, 2}, :orange, :pawn)
    |> placePiece({:e, 2}, :orange, :pawn)
    |> placePiece({:f, 2}, :orange, :pawn)
    |> placePiece({:g, 2}, :orange, :pawn)
    |> placePiece({:h, 2}, :orange, :pawn)
    # blue pawns
    |> placePiece({:a, 7}, :blue, :pawn)
    |> placePiece({:b, 7}, :blue, :pawn)
    |> placePiece({:c, 7}, :blue, :pawn)
    |> placePiece({:d, 7}, :blue, :pawn)
    |> placePiece({:e, 7}, :blue, :pawn)
    |> placePiece({:f, 7}, :blue, :pawn)
    |> placePiece({:g, 7}, :blue, :pawn)
    |> placePiece({:h, 7}, :blue, :pawn)
    # orange pieces
    |> placePiece({:a, 1}, :orange, :rook)
    |> placePiece({:b, 1}, :orange, :knight)
    |> placePiece({:c, 1}, :orange, :bishop)
    |> placePiece({:d, 1}, :orange, :queen)
    |> placePiece({:e, 1}, :orange, :king)
    |> placePiece({:f, 1}, :orange, :bishop)
    |> placePiece({:g, 1}, :orange, :knight)
    |> placePiece({:h, 1}, :orange, :rook)
    # blue pieces
    |> placePiece({:a, 8}, :blue, :rook)
    |> placePiece({:b, 8}, :blue, :knight)
    |> placePiece({:c, 8}, :blue, :bishop)
    |> placePiece({:d, 8}, :blue, :queen)
    |> placePiece({:e, 8}, :blue, :king)
    |> placePiece({:f, 8}, :blue, :bishop)
    |> placePiece({:g, 8}, :blue, :knight)
    |> placePiece({:h, 8}, :blue, :rook)
  end

  @doc """
  Convenience function:
  Given one color, switch to the other color (orange to blue, blue to orange)
  """
  def otherColor(:blue), do: :orange
  def otherColor(:orange), do: :blue

  #########################################
# TILE FUNCTIONS
  #########################################

  @doc """
  place one tile on the tileary
  """
  def placeTile(tileary, tileType, formal_location) do
    if isReplacingTile(tileary, formal_location) do
      raise BoardError, message: "existing tile at location to place tile"
    end

    tileary ++ [{tileType, formal_location}]
  end


  # a tileary is a collection of unusual tile placements that takes the form of a list of placements:
  # a placement is an item of the form {formal_location, tileType}, Only one formal_location have a an assigned tileType
  def isReplacingTile([], _formal_location), do: false
  def isReplacingTile(tileary, new_location) do
    Enum.reduce(tileary, false, fn {_tileType, existing_location} = _placement, acc -> existing_location == new_location or acc end)
  end

end
