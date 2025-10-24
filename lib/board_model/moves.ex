defmodule Moves do
  @moduledoc """
  The Moves module is responsible for generating a list of possible moves for a given piece.
  It will also prune based on location and color types of moves that cannot happen.
  The resulting moves will need to be further pruned by the location of other pieces on the board.
  (those that have obstructing pieces in the way, those that are altered by representing a captured, those that are )
  """
  #import MoveError

  #def expandDirectional(atom) when atom in @directional_moves, do: [directional_atom(atom, :left), directional_atom(atom, :right)]
  #def expandDirectional(atom), do: atom
  #def directional_atom(atom, direction), do: Kernel.<>(Atom.to_string(atom), Atom.to_string(direction)) |> String.to_atom()


  #@pawn_moves_expanded @pawn_moves |> Enum.map(&(&1 |> expandDirectional()))



  @only_possible_if_not_taking [:sprint, :march, :promote, :castle]
  #@only_possible_if_taking [:capture, :impaleEnPassanter, :capturepromote]
  @pawn_moves [:sprint, :march, :capture, :impaleEnPassanter, :promote, :capturepromote]
  @knight_moves [:gallop, :trot, :rear, :turnabout] ## unique about these is the jumping behavior
  @rook_moves [:advance, :retreat, :flank]
  @bishop_moves [:veer, :sidle]
  @queen_moves [:flank, :veer, :sidle, :advance, :retreat]
  #@queen_moves [ :advance, :retreat, :flank, :veer, :sidle]
  @king_moves [:forwardstep, :backstep, :sidestep, :duck, :roll, :shortcastle, :longcastle] # all of these but castle are non-n,
  #just one space moved, castle is unique as two spaces and directional
  @n_moves [:advance, :retreat, :flank, :veer, :sidle]
  @directional_moves [:sidestep, :flank, :veer, :sidle, :gallop, :trot, :rear, :turnabout, :capture, :impaleEnPassanter, :duck, :roll, :castle, :capturepromote]
  @jumping_moves @knight_moves
  @rankup_moves [:promote, :capturepromote]
  @in_bounds_atoms [:a, :b, :c, :d, :e, :f, :g, :h]
  @out_of_bounds_atoms [:i, :j, :k, :l, :m, :n, :o, :p, :"`", :"\_", :"^", :"]", :"\\", :"[", :Z, :Y]
  # n = 97           for x <- 1..8, do: <<n - x>>
  #["`", "_", "^", "]", "\\", "[", "Z", "Y"]

  @move_errors [:ob, :sprintstamina, :pawn_ob, :enpassant_misplaced, :unpromotable]
  #@move_returns [:traversing, :takeonly, :moveonly, :impale, :promoteknight, :promoterook, :promotebishop, :promotequeen, :castling, :jumping]
  # PAWN MOVES

  defguard second_to_last_row_orange(row) when row == 7
  defguard second_to_last_row_blue(row) when row == 2
  defguard last_row_orange(row) when row == 8
  defguard last_row_blue(row) when row == 1
  defguard first_row_orange(row) when last_row_blue(row)
  defguard first_row_blue(row) when last_row_orange(row)
  defguard pawn_not_misplaced(row) when row > 1 and row < 8
  defguard left_hand_file_orange(file) when file == :a
  defguard left_hand_file_blue(file) when file == :h
  defguard right_hand_file_orange(file) when left_hand_file_blue(file)
  defguard right_hand_file_blue(file) when left_hand_file_orange(file)
  defguard in_bounds_cols(col) when col in @in_bounds_atoms
  defguard ob_file(file) when file in @out_of_bounds_atoms
  defguard out_of_bounds_cols(col) when col not in @in_bounds_atoms

  @doc """
  Given a start loc, an end loc, and a board, infers the movetype
  """
  def infer_move_type(board, start_loc, _end_loc) do
    #moving_piece = Chessboard.get_at(board, start_loc)
    case Chessboard.get_at(board.placements, start_loc) do
      :mt -> :invalid_piece
      {_color, piece_type} ->
        #movetypes_possible = piece(piece_type)
        case piece_type do
          :knight -> :jumping
          :rook -> :not_jumping
          :bishop -> :not_jumping
          :queen -> :not_jumping
          :king -> :not_jumping
          :pawn -> :not_jumping
        end
    end
  end
  @doc """
  Given a start location, and end location and a pieceType, determines what the movetype is
  """
  def retrieveMoveType(start_loc, end_loc, _pieceType, _pieceColor) when start_loc == end_loc do
    :invalid
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :pawn, :orange) do
    cond do
      s_row == 1 -> :invalid
      s_row == 7 and e_row == 8 and e_col == s_col -> :promote
      s_row == 7 and e_row == 8 and Location.nextTo(e_col, s_col) -> :promotecapture
      s_row + 1 == e_row and s_col == e_col -> :march
      s_row + 1 == e_row and Location.nextTo(e_col, s_col) -> :capture
      s_row == 2 and e_row == 4 and s_col == e_col -> :sprint
      true -> :invalid # not heading forward or too far or random
    end
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :pawn, :blue) do
    cond do
      s_row == 8 -> :invalid
      s_row == 2 and e_row == 1 and e_col == s_col -> :promote
      s_row == 2 and e_row == 1 and Location.nextTo(e_col, s_col) -> :promotecapture
      e_row + 1 == s_row and s_col == e_col -> :march
      e_row + 1 == s_row and Location.nextTo(e_col, s_col) -> :capture
      s_row == 7 and e_row == 5 and s_col == e_col -> :sprint
      true -> :invalid # not heading forward or too far or random
    end
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :king, :orange) do
    cond do
      s_row == 1 and s_col == :e and e_row == 1 and e_col == :g -> :shortcastle # castle right
      s_row == 1 and s_col == :e and e_row == 1 and e_col == :c -> :longcastle # castle left
      Location.nextTo(s_col, e_col) and s_row == e_row -> :majestep
      Location.nextTo(s_row, e_row) and s_col == e_col -> :majestep
      Location.nextTo(s_col, e_col) and Location.nextTo(s_row, e_row) -> :majestep
      true -> :invalid ## beyond range of 1 step
    end
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :king, :blue) do
    cond do
      s_row == 8 and s_col == :e and e_row == 8 and e_col == :g -> :shortcastle # castle left
      s_row == 1 and s_col == :e and e_row == 1 and e_col == :c -> :longcastle # castle right
      Location.nextTo(s_col, e_col) and s_row == e_row -> :majestep
      Location.nextTo(s_row, e_row) and s_col == e_col -> :majestep
      Location.nextTo(s_row, e_row) and Location.nextTo(s_col, e_col) -> :majestep

      true -> :invalid ## beyond range of 1 step
    end
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :knight, _color) do
    s_col_i = s_col |> Board.Utils.column_to_int()
    e_col_i = e_col |> Board.Utils.column_to_int()
    cond do
      abs(s_col_i - e_col_i) == 1 and abs(s_row - e_row) == 2 -> :jump # gallop/turnabout
      abs(s_col_i - e_col_i) == 2 and abs(s_row - e_row) == 1 -> :jump # trot/rear
      true -> :invalid ## not the knight pattern
    end
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :bishop, _color) do
    s_col_i = s_col |> Board.Utils.column_to_int()
    e_col_i = e_col |> Board.Utils.column_to_int()
    on_diagonal = abs(e_col_i - s_col_i) == abs(e_row - s_row)
    if on_diagonal do
      :diagonal
    else
      :invalid
      # not on the diagonals reachable by the start_location
    end
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :rook, _color) do
    cond do
      s_col == e_col -> :vertical
      s_row == e_row -> :horizontal
      true -> :invalid # rooks only go horizontal or vertical
    end
  end

  def retrieveMoveType({s_col, s_row} = _start_loc, {e_col, e_row} = _end_loc, :queen, _color) do
    s_col_i = s_col |> Board.Utils.column_to_int()
    _e_col_i = e_col |> Board.Utils.column_to_int()
    cond do
      s_col == e_col -> :vertical
      s_row == e_row -> :horizontal
      abs(s_col_i - e_row) == abs(s_col_i - e_row) -> :diagonal
      true -> :invalid # queens only go diagonally, horizontally or vertically
    end
  end

  def jumping(:jumping), do: true
  def jumping(atom), do: atom in @jumping_moves
  def moveOnly(atom), do: atom in @only_possible_if_not_taking

  def capture({_col, rank} = _loc, _color, _direction) when not pawn_not_misplaced(rank), do: :pawn_misplaced
  def capture({col, rank} = loc, :orange, :left) when pawn_not_misplaced(rank) and not left_hand_file_orange(col), do: veer(loc, :orange, :left, 1)
  def capture({col, rank} = loc, :orange, :right) when pawn_not_misplaced(rank) and not right_hand_file_orange(col), do: veer(loc, :orange, :right, 1)
  def capture({col, rank} = loc, :blue, :left) when pawn_not_misplaced(rank) and not left_hand_file_blue(col), do: veer(loc, :blue, :left, 1)
  def capture({col, rank} = loc, :blue, :right) when pawn_not_misplaced(rank) and not right_hand_file_blue(col), do: veer(loc, :blue, :right, 1)
  def capture(loc, color, direction), do: veer(loc, color, direction, 1)



  def promote({_col, rank} = loc, :orange, promote_to) when second_to_last_row_orange(rank), do: {{:orange, promote_to}, march(loc, :orange)}
  def promote({_col, rank} = loc, :blue, promote_to) when second_to_last_row_blue(rank), do: {{:blue, promote_to}, march(loc, :blue)}
  def promote(_loc, _color, _promote_to), do: :unpromotable

  def capturepromote({_col, rank} = loc, :orange, promote_to, direction) when second_to_last_row_orange(rank), do: {{:orange, promote_to}, capture(loc, :orange, direction)}
  def capturepromote({_col, rank} = loc, :blue, promote_to, direction) when second_to_last_row_blue(rank), do: {{:blue, promote_to}, capture(loc, :blue, direction)}
  def capturepromote(_loc, _color, _promote_to, _direction), do: :unpromotable

  def replaceMovetype({_movetype, loc}, newType), do: {newType, loc}
  def removeMovetype({_, loc}), do: loc

  def sprint({_col, rank} = loc, :orange) when rank == 2, do: advance(loc, :orange, 2)
  def sprint({_col, rank} = loc, :blue) when rank == 7, do: advance(loc, :blue, 2)
  def sprint(_loc, _color), do: :sprintstamina

  def march({_col, rank} = loc, color) when rank > 1 and rank < 8, do: advance(loc, color, 1)
  def march(_loc, _color), do: :pawn_misplaced
  # pawn marches, king forwardsteps
  # pawns can capture or march to prompt a rankup, rankup is a special move
  # that is only the second part of a move. It is one move to capture and rankup, but
  # two functions. That's fine

  def impaleEnPassanter({_col, rank} = loc, :orange, direction) when rank == 5, do: veer(loc, :orange, direction, 1)
  def impaleEnPassanter({_col, rank} = loc, :blue, direction) when rank == 4, do: veer(loc, :blue, direction, 1)
  def impaleEnPassanter({_col, _rank} = _loc, _color, _direction), do: :enpassant_misplaced

  # also need logic to say can only happen if the location you're enpassanting has a pawn behind it (in the view of the capturing piece)

  # this doesn't make sense yet, need to figure out what to return here
  # def rankUp({col, rank}, :orange, rankUpType), do: {col, rank + 1}
  # def rankUp({col, rank}, :blue, rankUpType), do: {col, rank - 1}

  # KNIGHT MOVES
  def gallop(loc, color, direction), do: advance(loc, color, 1) |> veer(color, direction, 1)

  def trot(loc, color, direction), do: flank(loc, color, direction, 1) |> veer(color, direction, 1)

  def rear(loc, color, direction), do: flank(loc, color, direction, 1) |> sidle(color, direction, 1)

  def turnabout(loc, color, direction), do: retreat(loc, color, 1) |> sidle(color, direction, 1)

  # ROOK MOVES
  def advance({col, rank}, :orange, n) when (n + rank) < 9, do: {col, rank + n}
  def advance({col, rank}, :blue, n) when (rank - n) > 0, do: {col, rank - n}
  def advance(_loc, _color, _n), do: :ob

  def retreat({col, rank}, :orange, n) when (rank - n) >= 1, do: {col, rank - n}
  def retreat({col, rank}, :blue, n) when (rank + n) <= 8, do: {col, rank + n}
  def retreat(_loc, _color, _n), do: :ob

  #def vertical_helper(ending_rank, col) when out_of_bounds_rank(ending_rank), do: :ob
  #def vertical_helper(ending_rank, col), do: {col, ending_rank}

  def flank({col, rank}, :orange, :right, n), do: formalColumnAddition(col, n) |> flank_helper(rank)
  def flank({col, rank}, :blue, :right, n), do: formalColumnAddition(col, -n) |> flank_helper(rank)
  def flank({col, rank}, :orange, :left, n), do: formalColumnAddition(col, -n) |> flank_helper(rank)
  def flank({col, rank}, :blue, :left, n), do: formalColumnAddition(col, n) |> flank_helper(rank)

  def flank(loc, dir, n, color), do: flank(loc, color, dir, n)

  def flank_helper(ending_col, rank) when in_bounds_cols(ending_col), do: {ending_col, rank}
  def flank_helper(ending_col, _rank) when out_of_bounds_cols(ending_col), do: :ob

  #def questionMark(<<raw>>), do: raw
  def cloak_in_binary(raw), do: <<raw>>

  # helpful conversion function, should be in utils
  def formalColumnAddition(col, num) do
    col #:a
    |> Atom.to_string()
    |> String.to_charlist()
    |> Enum.at(0)
    |> Kernel.+(num)
    |> cloak_in_binary()
    |> String.to_existing_atom()
  end

  # BISHOP MOVES
  def veer(loc, color, direction, n) do
    case advance(loc, color, n) do
      :ob -> :ob
      forward -> flank(forward, color, direction, n)
    end
  end
  #def veer(loc, color, direction, n), do: advance(loc, color, n) |> flank(color, direction, n)


  def sidle(loc, color, direction, n) do
    case retreat(loc, color, n) do
      :ob -> :ob
      backward -> flank(backward, color, direction, n)
    end
  end
  #def sidle(loc, color, direction, n), do: retreat(loc, color, n) |> flank(color, direction, n)

  # QUEEN MOVES
  # Lol no new ones

  # KING MOVES
  def forwardstep(loc, color), do: advance(loc, color, 1)
  def sidestep(loc, color, direction), do: flank(loc, color, direction, 1)
  def backstep(loc, color), do: retreat(loc, color, 1)
  def duck(loc, color, direction), do: veer(loc, color, direction, 1)
  def roll(loc, color, direction), do: sidle(loc, color, direction, 1)
  def shortcastle({_e, _1} = loc, :orange), do: flank(loc, :orange, :right, 2)
  def shortcastle({_e, _8} = loc, :blue), do: flank(loc, :blue, :left, 2)
  def shortcastle(_loc, _any), do: :invalid

  def longcastle({_e, _1} = loc, :orange), do: flank(loc, :orange, :left, 2)
  def longcastle({_e, _8} = loc, :blue), do: flank(loc, :blue, :right, 2)
  def longcastle(_loc, _color), do: :invalid

  # so all moves are defined in absence of their mover, possible places to move are generated,
  # then the boardsize is imposed, so moves that are off the board are filtered out,
  # then blockers are identified?, the moves that are blocked are filtered out, then captures are identified,
  # so then friendly captures are filtered out, then the moves that rank up are identified, and the moves that are rank ups are added to the list of moves,
  # then the king_loc is identified, and the moves that would put the king in check are filtered out

  def piece(:pawn), do: @pawn_moves
  def piece(:knight), do: @knight_moves
  def piece(:rook), do: @rook_moves
  def piece(:bishop), do: @bishop_moves
  def piece(:queen), do: @queen_moves
  def piece(:king), do: @king_moves

  @doc """
  Given a pieceColor, pieceType, location -
  Grab the piecetype list of possible move types,
  Make them enumerate left and right options as tuples
  Make them enumerate n options as tuples
  flatten em to get rid of nesting building up
  put everything into lists in order [movetype, direction, n]
  add a location and pieceolor in so [movetype, location, piececolor, direction, n]
  run the movetype as a function (using apply) getting a tuple of movetype and ending location
  the ending location can be :ob, so reject those

  there you have the unappraised move options for a piece

  TODO add more? i dunno
  ADD SUPPORT FOR EXPANDING RANKUPS
  """
  def unappraised_moves(pieceColor, pieceType, location) do
    #{pieceColor, :pawn, location, pawn}
    piece(pieceType)
    # so just a tame list [:sprint, :impaleEnPassanter, :advance, :flank]
    |> Enum.map(fn movetype ->
      if movetype in @rankup_moves do
        [{movetype, :knight}, {movetype, :rook}, {movetype, :bishop}, {movetype, :queen}]
      else
        movetype
      end
  end)
  |> List.flatten()
    |> Enum.map(fn
      movetype when is_atom(movetype)->
        if movetype in @directional_moves do
          [{movetype, :left}, {movetype, :right}]
        else
          movetype
        end
      {movetype, promote_type} = same ->
        if movetype in @directional_moves do
          [{movetype, promote_type, :left}, {movetype, promote_type, :right}]
        else
          same
        end
    end)
    # we just added movetype tuples [:sprint, {:impaleEnPassanter, :left}, {:impaleEnPassanter, :right}, :advance, {:flank, :left}, {:flank, :right}]
    |> List.flatten()
    |> Enum.map(fn
      {move, atom} when move in @n_moves -> [{move, atom, 1}, {move, atom, 2}, {move, atom, 3}, {move, atom, 4}, {move, atom, 5}, {move, atom, 6}, {move, atom, 7}]
      move ->
        if move in @n_moves do
          [{move, 1}, {move, 2}, {move, 3}, {move, 4}, {move, 5}, {move, 6}, {move, 7}]
        else
          move
        end
    end)
    # now added n tuples [:sprint, {:impaleEnPassanter, :left}, {:impaleEnPassanter, :right},
    # [{:advance, 1}, {:advance, 2} ... {:advance, 8}],
    # [{{:flank, :right}, 1}, ... {{:flank, :right}, 8},
    # {{:flank, :left}, 1} ... {{:flank, :left}, 8}]]
    |> List.flatten()
    # nice and flat
    # [:sprint, {:impaleEnPassanter, :left}, {:impaleEnPassanter, :right},
    # {:advance, 1}, {:advance, 2} ... {:advance, 8},
    # {{:flank, :right}, 1}, ... {{:flank, :right}, 8},
    # {{:flank, :left}, 1} ... {{:flank, :left}, 8}]
    |> Enum.map(fn
      movetype when is_tuple(movetype) -> Tuple.to_list(movetype)
      any -> any
    end)
    # [:sprint, [:impaleEnPassanter, :left], [:impaleEnPassanter, :right],
    # [:advance, 1], [:advance, 2] ... [:advance, 8],
    # [{:flank, :right}, 1], ... [{:flank, :right}, 8],
    # [{:flank, :left}, 1] ... [{:flank, :left}, 8]]
    |> Enum.map(
      fn
        [movetype | n] when is_tuple(movetype) -> Tuple.to_list(movetype) ++ [n]
        movetype when is_list(movetype) -> movetype
        movetype when is_atom(movetype) -> [movetype]
        any -> any
      end)
    # [
    #   [:sprint], [:impaleEnPassanter, :left], [:impaleEnPassanter, :right],
    #   [:advance, 1], [:advance, 2] ... [:advance, 8],
    #   [:flank, :right, 1], ... [:flank, :right, 8],
    #   [:flank, :left, 1] ... [:flank, :left, 8]
    # ]
    |> Enum.map(fn [movetype | args] -> [movetype | [location | [pieceColor | args]]] end)
    # [
    #   [:sprint, location, pieceColor], [:impaleEnPassanter, location, pieceColor, :left], [:impaleEnPassanter, location, pieceColor, :right],
    #   [:advance, location, pieceColor, 1], [:advance, location, pieceColor, 2] ... [:advance, location, pieceColor, 8],
    #   [:flank, location, pieceColor, :right, 1], ... [:flank, location, pieceColor, :right, 8],
    #   [:flank, location, pieceColor, :left, 1] ... [:flank, location, pieceColor, :left, 8]
    # ]
    |> Enum.map(fn [movetype | args] -> {movetype, apply(__MODULE__, movetype, args)} end)
    # for location={d, 2}, pieceType=pawn, pieceColor=orange
    # [
    #   {:sprint, {d, 4}}, {:impale, {c, 3}}, {:impale, {e, 3}},
    # {:advance, {d, 3}}, {:advance, {d, 4}}, {:advance, {d, 5}},
    # {:advance, {d, 6}}, {:advance, {d, 7}}, {:advance, {d, 8}},
    # {:advance, :ob}, {:advance,  :ob},
    # {:flank, {e, 2}}, {:flank, {f, 2}}, {:flank, {g, 2}}, {:flank, {h, 2}},
    # {:flank, :ob}, {:flank, :ob}, {:flank, :ob}, {:flank, :ob},
    # {:flank, {c, 2}}, {:flank, {b, 2}}, {:flank, {a, 2}}, {:flank, :ob},
    # {:flank, :ob}, {:flank, :ob}, {:flank, :ob}, {:flank, :ob}
    # ]
    |> Enum.reject(fn {_movetype, end_loc} -> end_loc in @move_errors end)
    # [
    #   {:sprint, {d, 4}}, {:impale, {c, 3}}, {:impale, {e, 3}},
    # {:advance, {d, 3}}, {:advance, {d, 4}}, {:advance, {d, 5}},
    # {:advance, {d, 6}}, {:advance, {d, 7}}, {:advance, {d, 8}},
    # {:flank, {e, 2}}, {:flank, {f, 2}}, {:flank, {g, 2}}, {:flank, {h, 2}},
    # {:flank, {c, 2}}, {:flank, {b, 2}}, {:flank, {a, 2}}
    # ]
    #|> Enum.map(fn {movetype, end_loc} -> {movetype, end_loc} end)

    # Order: location, pieceColor, direction, n
    # Order: location, pieceColor, n
    # Order: location, pieceColor, direction
    # Order: location, pieceColor
    # Order: location, pieceColor, promotepiecetype, direction
  end

  # a piece on the board always has a direction they're facing, is determined by piece color
  #Move.shortCastleLeft()
  ## two left, if the piece at the location {e, 8} is a blue king and it has not moved and the rook to it's left hasn't moved,
  # the king is not in check and the space to the left {f, 8} and the space to the left again {g, 8} are not threatened
  #Move.shortCastleRight() ## two right, if the piece at the location {e, 1} is an orange king and it has not moved,
  # and the rook to the right hasn't moved, the king is not in check and spaces to right 2 are not threatened ({})
  #Move.longCastleLeft() ## two left, if the piece is a king and it has not moved, rook to it's left hasn't moved,
  # the king is not in check, the space to the left and the left of that space are not being threatened
  #Move.longCastleRight() ## two right, if the piece is a king and it has not moved
end
