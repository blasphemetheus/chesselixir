
defmodule UrBoard do
@moduledoc """
An implementation of an Ur Box and Board, complete with a drawer.
There are 3 by 8 UrTiles, of which 4 are out_of_play. There is a drawer as well.
And there are 8 tetrahedron dice with one active corner

Later might add support for a 3 x 12 board, but not right now
"""
alias ExUnit.DocTest.Error

import Board.Utils
## Module Attributes ##
@length 3
@width 8
@drawer_compartments 1
@pyramidal_dice 8
@counters 11
@sides [:orange, :blue] # order doesn't intrinsically come from the piece color, it's decided by the players
@square_type [:rosette, :water, :ice, :eyes, :plasma]
@starting_drawer :empty
@realms [:earth, :hell, :heaven]
@starting_limbo {11, 11}
@orange_home {1, 5}
@blue_home {3, 5}
@conventional_tiles [[:rosette, :eyes, :water, :eyes, :home, :end, :rosette, :plasma],
                     [:crystal, :water, :ice, :rosette, :water, :ice, :eyes, :water],
                     [:rosette, :eyes, :water, :eyes, :home, :end, :rosette, :plasma]]
@location_list [
  [{1, 1}, {1, 2}, {1, 3}, {1, 4}, {1, 5}, {1, 6}, {1, 7}, {1, 8}],
  [{2, 1}, {2, 2}, {2, 3}, {2, 4}, {2, 5}, {2, 6}, {2, 7}, {2, 8}],
  [{3, 1}, {3, 2}, {3, 3}, {3, 4}, {3, 5}, {3, 6}, {3, 7}, {3, 8}],
]

# there should be the The Royal Game, Spartan Games and Finkel rule
# sets supported (three ways to play)

@doc """
Define %UrBoard{} struct.
"""
defstruct length: @length,
          width: @width,
          tiles: @conventional_tiles,
          placements: [],
          order: @sides,
          drawer: @starting_drawer,
          out_of_play: @starting_limbo

defguard onboard(w, l) when is_integer(w) and is_integer(l) and l <= 7 and l >= 0 and w <= 2 and w >= 0


# def otherColor(:blue), do: :orange
# def otherColor(:orange), do: :blue


@doc """
Creates a board, ready to play ur on
"""
def createBoard() do
  %UrBoard{
    placements: startingPosition()
  }
end

@doc """
Given placements (3 by 8) in the ur fashion and a line separator, print the
Ur Board to Command Line
"""
def printPlacements(urboard, line_sep \\ "\n") when is_struct(urboard) do
  inspect(urboard, label: "urboard")
  printPlacements(urboard.placements, urboard.tiles, line_sep)
end

def printPlacements(placements, tiles, line_sep) do
  inspect(placements, label: "placements")
  inspect(tiles, label: "tiles")

  tiles
  # zip twice (ranks then placements)
  |> Enum.zip_with(placements,
  fn (tile_rank, place_rank) ->
    Enum.zip_with(tile_rank, place_rank,
    fn
      tile, placement -> {tile, placement}
   end)
  end
  )
  |> Board.Utils.map_to_each(&translate_ur/1)
  |> Enum.reduce("", fn x, accum -> accum <> Enum.reduce(x, "", fn item, acc -> acc <> item end) end)



  # Enum.intersperse(tiles, placements)
  # |> Enum.chunk_every(2)
  # |> Enum.map(fn [tile, placement] -> {tile, placement} end)
  # # |> Board.Utils.reverseRanks()
  # #|> Enum.intersperse(:switch_tiles)
  # |> Enum.map(fn
  #   x -> printRank(:ur, x, "\t ") <> line_sep
  #   end) |> to_string() |> inspect()

  #Enum.intersperse()
  # Tile.renderTile(:blue)
  # Tile.renderTile(:orange)

  # we need nested tile colors to zip into the board
  # Tile.nestedTileColors()
  # # so we must zip TWICE (zip ranks, zip placements)
  # |> Enum.zip_with(placements,
  #   fn (tile_color_rank, board_rank) ->
  #     Enum.zip_with(tile_color_rank, board_rank, fn
  #       tile_color, :mt -> tile_color
  #       _tile_color, not_empty -> not_empty
  #       end)
  #     end)
  # ## |> Enum.map(fn x -> Enum.chunk_every(x, 2) |> List.to_tuple() end)
  # |> Board.Utils.map_to_each(&translate_ur/1)
  # |> Enum.reduce("", fn x, accum -> accum <> Enum.reduce(x, "", fn item, acc -> acc <> item end) end)
end

def get_first_if_list(possible_list) when possible_list |> is_list() do
  List.first(possible_list)
end

def get_first_if_list(possible_list) do
  possible_list
end

@doc """
Given an urboard, a start_loc, end_loc and turn (color) return a result tuple with the new_board state after the move
"""
def move(urboard, start_loc, end_loc, move_color) do
  # todo : currently does not remove when moving chit
  placements = urboard.placements
  moving_piece = get_pretty_at(placements, start_loc) |> get_first_if_list()

  end_loc_placement = get_pretty_at(placements, end_loc)

  if end_loc_placement == {move_color, :chit} do
    {:error, "taking own chit, cannot make move"}
  else
    new_placements = placements |> remove_first_at(start_loc) |> replace_at(end_loc, moving_piece)

    {:ok, %{urboard | placements: new_placements}}
  end
end

def remove_only_first_chit([first | rest] = starting_placement_precise) do
  first
end

def remove_only_first_chit([first] = starting_placement) do
  first
end

def remove_only_first_chit([]) do
  :mt
end

def remove_at(placements, location) do
  placements
  |> replace_at(location, :mt)
end

def remove_first_at(placements, {row, col} = location) do
  placements
  rank = placements |> Enum.at(row - 1)
  existing_precise = Enum.at(rank, col - 1)
  changed_precise = existing_precise |> remove_only_first_chit()
  new_rank = List.replace_at(rank, col - 1, changed_precise)

  List.replace_at(placements, row - 1, new_rank)
end

def replace_at(placements, {row, col} = location, replacing) do
  rank = placements |> Enum.at(row - 1)
  new_rank = List.replace_at(rank, col - 1, replacing)

  List.replace_at(placements, row - 1, new_rank)
end

def get_tile_at(tiles_2d_list, loc) do
  get_pretty_at(tiles_2d_list, loc)
end

@doc """
Given an urboard and and integer representation of a roll (so 0 through 4) returns whether
the urboard has made a move available for the player whose turn it is.

is_there_a_move_available(%UrBoard{placements: mt_placements_ur()}) == true
"""
def is_there_a_move_available(urboard, int_roll, turn) do
  # so three choices here,
  # - interweave locations and tiles into placements, process all
  # - use a LinkedUrLocation which tracks tile and contents (chits) and implement
  #   this_many_ahead to use orange or blue paths
  # - a for loop which constructs the location from each
  condensed_placements = urboard.placements
  |> condense_home_list()

  empty_huh = urboard.tiles
  |> interweave_2D_lists(@location_list, condensed_placements)
  |> List.flatten()
  |> Enum.map(fn
    {tile, start_location, :mt} -> :not_available
    {tile, start_location, {turn, :chit}} ->
      ahead_loc = this_many_ahead(start_location, int_roll, turn)

      if ahead_loc == nil do
        :not_available
      else
        ahead_contents = get_pretty_at(condensed_placements, ahead_loc) # is this making sense? todo
        ahead_tile = get_tile_at(urboard.tiles, ahead_loc)
        case ahead_contents do
          :mt -> {:open, start_location, ahead_loc}
          {turn, :chit} -> :notavailable
          {color, :chit} ->
            case ahead_tile do
              :rosette -> :notavailable
              all_other_tiles -> {:taking_enemy, start_location, ahead_loc}
            end
        end
      end

    {tile, location, {other_color, :chit}} -> :enemy_chit
  end)
  |> Enum.filter(fn
    {:taking_enemy, start_loc, end_loc} -> true
    {:open, start_loc, end_loc} -> true
    any -> false
  end)
  |> Enum.empty?()

  not empty_huh
end

@doc """
Given a placements and a rank and col, return what is contained
"""
def get_at(placements, {rank, col}) when is_integer(rank) and is_integer(col) do
  placements
  |> Enum.at(rank)
  |> Enum.at(col)
end

def get_pretty_at(placements, {rank, col}) when is_integer(rank) and is_integer(col) do
  placements
  |> Enum.at(rank - 1)
  |> Enum.at(col - 1)
end

@doc """
Given an urboard and a turn, return a list of all possible moves
"""
def possible_moves(urboard, turn) do
  condensed_placements = urboard.placements
  |> condense_home_list()

  condensed_placements
  |> interweave_2D_lists(urboard.tiles, @location_list)
  |> Enum.map(fn
    {:mt, tile, start_location} -> nil
    {{turn, :chit}, tile, start_location} ->
      possible_moves_list_with_nils = for roll <- 1..4  do
        ahead_loc = this_many_ahead(start_location, roll, turn)
        at_ahead_loc = get_at(condensed_placements, ahead_loc)
        other_color = otherColor(turn)
        cond do
          ahead_loc == nil -> nil
          at_ahead_loc != :mt ->
            cond do
              at_ahead_loc == {turn, :chit} ->
                nil
              at_ahead_loc == {other_color, :chit} and tile == :rosette ->
                nil
              at_ahead_loc == {other_color, :chit} and tile != :rosette ->
                {start_location, ahead_loc, turn, :take}
            end
          get_at(condensed_placements, ahead_loc) == :mt ->
            {start_location, ahead_loc, turn, :move}
        end
      end

      possible_moves_list_with_nils
      |> List.flatten()
      |> Enum.reject(&is_nil/1)
      |> inspect()

    {tile, location, {_other_color, :chit}} -> nil

  end)
  |> inspect()
end

def otherColor(:blue), do: :orange
def otherColor(:orange), do: :blue


@doc """
Given a start location and a number of places ahead, charts along the path and returns the location
that many ahead, or nil if there is no such location
"""
def one_forward({1, 5}, :orange), do: {1, 4}
def one_forward({1, 4}, :orange), do: {1, 3}
def one_forward({1, 3}, :orange), do: {1, 2}
def one_forward({1, 2}, :orange), do: {1, 1}
def one_forward({1, 1}, :orange), do: {2, 1}
def one_forward({2, 1}, :orange), do: {2, 2}
def one_forward({2, 2}, :orange), do: {2, 3}
def one_forward({2, 3}, :orange), do: {2, 4}
def one_forward({2, 4}, :orange), do: {2, 5}
def one_forward({2, 5}, :orange), do: {2, 6}
def one_forward({2, 6}, :orange), do: {2, 7}
def one_forward({2, 7}, :orange), do: {2, 8}
def one_forward({2, 8}, :orange), do: {1, 8}
def one_forward({1, 8}, :orange), do: {1, 7}
def one_forward({1, 7}, :orange), do: {1, 6}
def one_forward({3, 5}, :blue), do: {3, 4}
def one_forward({3, 4}, :blue), do: {3, 3}
def one_forward({3, 3}, :blue), do: {3, 2}
def one_forward({3, 2}, :blue), do: {3, 1}
def one_forward({3, 1}, :blue), do: {2, 1}
def one_forward({2, 1}, :blue), do: {2, 2}
def one_forward({2, 2}, :blue), do: {2, 3}
def one_forward({2, 3}, :blue), do: {2, 4}
def one_forward({2, 4}, :blue), do: {2, 5}
def one_forward({2, 5}, :blue), do: {2, 6}
def one_forward({2, 6}, :blue), do: {2, 7}
def one_forward({2, 7}, :blue), do: {2, 8}
def one_forward({2, 8}, :blue), do: {3, 8}
def one_forward({3, 8}, :blue), do: {3, 7}
def one_forward({3, 7}, :blue), do: {3, 6}
def one_forward({_rank, _file} = _any_loc, _color), do: nil

def this_many_ahead({rank, col} = start_location, 1, turn_color), do: one_forward(start_location, turn_color)
def this_many_ahead({rank, col} = start_location, 0, turn_color), do: start_location
def this_many_ahead({rank, col} = start_location, number_ahead, turn_color) when number_ahead > 1 do
  this_many_ahead(one_forward(start_location, turn_color), number_ahead - 1, turn_color)
end

def are_there_any_chits_of_color(urboard, turn) do
  urboard.placements
  |> condense_home_list()
  |> Enum.any?(fn
    :mt -> false
    {turn, :chit} -> true
  end)
end

@doc """
Given a list of placements (condensed), a second list, and a third list of the same shape, combine them into one list, tupelized
"""
def interweave_2D_lists(first_list, second_list, third_list) do
  Enum.zip(first_list, second_list)
  |> Enum.map(fn
    {first_row, second_row} -> Enum.zip(first_row, second_row)
    end)
  |> Enum.zip(third_list)
  |> Enum.map(fn
    {combined_row, third_row} -> Enum.zip(combined_row, third_row)
  end)
  |> Enum.map(&(&1 |> Enum.map(fn
    {{first, second} = combined, third} -> {first, second, third}
  end)))
end

def tiles() do
  @conventional_tiles
end

def locs() do
  @location_list
end

@orange_path LinkedUrLocation.new
    |> LinkedUrLocation.push(:home, {1, 5})
    |> LinkedUrLocation.push(:eyes, {1, 4})
    |> LinkedUrLocation.push(:water, {1, 3})
    |> LinkedUrLocation.push(:eyes, {1, 2})
    |> LinkedUrLocation.push(:rosette, {1, 1})
    |> LinkedUrLocation.push(:crystal, {2, 1})
    |> LinkedUrLocation.push(:water, {2, 2})
    |> LinkedUrLocation.push(:ice, {2, 3})
    |> LinkedUrLocation.push(:rosette, {2, 4})
    |> LinkedUrLocation.push(:water, {2, 5})
    |> LinkedUrLocation.push(:ice, {2, 6})
    |> LinkedUrLocation.push(:eyes, {2, 7})
    |> LinkedUrLocation.push(:water, {2, 8})
    |> LinkedUrLocation.push(:plasma, {1, 8})
    |> LinkedUrLocation.push(:rosette, {1, 7})
    |> LinkedUrLocation.push(:end, {1, 6})


@blue_path LinkedUrLocation.new
    |> LinkedUrLocation.push(:home, {3, 5})
    |> LinkedUrLocation.push(:eyes, {3, 4})
    |> LinkedUrLocation.push(:water, {3, 3})
    |> LinkedUrLocation.push(:eyes, {3, 2})
    |> LinkedUrLocation.push(:rosette, {3, 1})
    |> LinkedUrLocation.push(:crystal, {2, 1})
    |> LinkedUrLocation.push(:water, {2, 2})
    |> LinkedUrLocation.push(:ice, {2, 3})
    |> LinkedUrLocation.push(:rosette, {2, 4})
    |> LinkedUrLocation.push(:water, {2, 5})
    |> LinkedUrLocation.push(:ice, {2, 6})
    |> LinkedUrLocation.push(:eyes, {2, 7})
    |> LinkedUrLocation.push(:water, {2, 8})
    |> LinkedUrLocation.push(:plasma, {3, 8})
    |> LinkedUrLocation.push(:rosette, {3, 7})
    |> LinkedUrLocation.push(:end, {3, 6})


@doc """
Given a placement list, return a placement list with any internal lists reduced to the first element
(so 11 to 1 chit on home for instance)
"""
def condense_home_list(placement_list) do
  placement_list
  |> Enum.map(fn
    row when is_list(row) -> Enum.map(row, fn
      alist when is_list(alist) -> Enum.at(alist, 0)
      tuple when is_tuple(tuple) -> tuple
      :mt -> :mt
    end)
  end)
end


###### UR Game Rules ####### move to Ur model or ur_game.ex or smth
# this function should be in random utils or whatever
@doc """
Roll
"""
def roll_pyramids_sum(amount) do
  # a corner can be :blank or :marked
  roll_pyramids_list(amount)
  |> Enum.sum()
end

@doc """
Given an amount of tetrahedrons (3D pyramids) to roll, return a list of values (from 0 to 1) that were rolled
"""
def roll_pyramids_list(amount) do
  # a corner can be :blank or :marked
  1..amount
  |> Enum.map(fn x -> roll_tetrahedron() end)
end

@doc """
Roll one tetrahedron with default reandomness approximately, returning a 0 for unmarked and 1 for marked
"""
def roll_tetrahedron() do
  upside = Enum.random([:blank, :blank, :marked, :marked])
  case upside do
    :blank -> 0
    :marked -> 1
  end
end


@doc """
Given an urboard (doesn't matter whose turn) and returns whether the position is final
"""
def isOver(urboard) do
  # over when 7 pieces make it to a home space
  scored_seven(urboard.placements, :orange) or scored_seven(urboard.placements, :blue)
end

@doc """
Given placements and  color, returns whether that color has seven in their end square
"""
def scored_seven(placements, color) do
  placements
  |> Enum.at(0)
  |> Enum.at(5)
  |> is_it_seven_chits_of_color(color)
end

def is_it_seven_chits_of_color(alist, color) when is_list(alist) and is_atom(color) do
    length(alist) == 7 and Enum.all?(fn
      {color, :chit} -> true
      {_color, _any} -> false
  end)
end

def is_it_seven_chits_of_color(alist, color) do
  false
end

@doc """
Creates a starting position, placing all chits on the board
"""
def startingPosition() do
  Board.Utils.make2DList(8, 3)
  |> placeMultipleOfPiece(:orange, :chit, 11, @orange_home)
  |> placeMultipleOfPiece(:blue, :chit, 11, @blue_home)
end

@doc """
insert a piece into the placements list of lists given a location ie (0, 0)
ase well as piececolor, piecetype and number of pieces to place

It should be noted that for ur, there can be multiple pieces at a location, but there
usually isn't
"""
def placeMultipleOfPiece(two_d_list, piece_color, piece_type, number_o_piece, {row, col} = loc) when is_integer(number_o_piece) do
  old_col = two_d_list |> Enum.at(row - 1)
  old_rank = old_col |> Enum.at(col - 1)
  new_rank = case old_rank do
     o when is_list(o) -> o ++ for x <- 1..number_o_piece, do: {piece_color, piece_type}
     :mt -> for x <- 1..number_o_piece, do: {piece_color, piece_type}
  end
  new_col = List.replace_at(old_col, col - 1, new_rank)

  List.replace_at(two_d_list, row - 1, new_col)
end

@doc"""
Given a position, return the atom representing the square type at that posn
"""
def square_type(w, l) when onboard(w, l) do
  case w do
    1 -> case l do
      0 -> :crystal
      1 -> :water
      2 -> :ice
      3 -> :rosette
      4 -> :water
      5 -> :ice
      6 -> :eyes
      7 -> :water
    end
    _ -> case l do
      0 -> :rosette
      1 -> :eyes
      2 -> :water
      3 -> :eyes
      4 -> :home
      5 -> :end
      6 -> :rosette
      7 -> :plasma
    end
  end
end

@doc """
Given an w and l coordinate (raw), returns whether the posn is in heaven (the top side of the board, the head).
"""
def in_heaven(w, l) when onboard(w, l) do
  l == 6 or l == 7
end


@doc """
Given an w and l coord (raw), returns whether the posn is in hell (the bridge, or the neck)
"""
def in_hell(w, l) when onboard(w, l) do
  w == 1 and (l == 4 or l == 5)
end


@doc """
Given an w and l coord (raw), returns whether the posn is in limbo (the start and end squares, not on board).
"""
def in_limbo(w, l) when onboard(w, l) do
  w != 1 and (l == 4 or l == 5)
end


@doc """
Given an w and l coord (raw), returns whether the posn is on earth (the main stretch).
"""
def on_earth(w, l) when onboard(w, l) do
  l < 4
end


@doc """
Given an w and l coord (raw), returns whether the posn is on the upside (topside, goes first usually)
"""
def upside(w, l) when onboard(w, l) do
  w == 0
end


@doc """
Given an w and l coord (raw) returns whether the posn is on the downside (bottom, goes second usually, underworld)
"""
def downside(w, l) when onboard(w, l) do
  w == 2
end

end
