defmodule GameRunner do
  @moduledoc """
  All about the GameRunner
  """
  #import GameError
  import Chessboard
  import UrBoard
  #import Player
  import Chesselixir.View.CLI

  @board_games [:chess, :ur]
  @modulize_board_games %{chess: Chessboard, ur: UrBoard}
  @default_game :chess

  #@resolutions [:win, :loss, :drawn, :bye]
  #@end_reasons [:checkmate, :stalemate, :resignation, :timeout, :draw, :disconnection, :other]
  #@play_types [:vs, :online, :cpu_vs_cpu, :human_vs_cpu, :cpu_vs_human]

  @doc """
  a Board is a struct which holds turn (atom), first (player struct), second (likewise, opposite color though),
  status (built is default), history (a list), resolution (atom), reason (atom)
  """
  defstruct board: %Chessboard{},
            bgame: :unset,
            turn: :orange,
            first: %Player{color: :orange},
            second: %Player{color: :blue},
            status: :built,
            history: [],
            resolution: nil,
            reason: nil

  defguard a_bgame(bg) when bg in @board_games


  @doc """
  given a string, returns the correct atom based on whether local or remote is in the string, or raises an error
  """
  def assignLocalOrRemote(player) do
    cond do
      String.contains?(player, "local") -> :local
      String.contains?(player, "remote") -> :remote
      true -> raise "Invalid Online player type"
    end
  end

  def modulizeGame(bgame) when a_bgame(bgame), do: @modulize_board_games[bgame]

  @doc """
  Given a tag and an opponent tag, tells view to display as a local game and starts Board from starting position,
  showing the game status in between
  """
  def playLocal(bgame, tag \\ "BRAG", opponent \\ "GRED") when is_atom(bgame) do
    game_module = modulizeGame(bgame)

    game_module.startingPosition()
    |> showGameStatus({tag, opponent}, {[], []}, 0, 0)
    |> playTurn(bgame, tag, "first")
    |> showGameStatus({tag, opponent}, {[], []}, 0, 0)
    |> playTurn(bgame, opponent, "second")
    |> showGameStatus({tag, opponent}, {[], []}, 0, 1)
  end

  # @doc """
  # The passing the module version
  # """
  # def playLocal(tag \\ "cool", opponent \\ "guy") do
  #   View.CLI.displays(:local, tag, opponent)

  #   Chessboard.startingPosition()
  #   |> showGameStatus({tag, opponent}, {[], []}, 0, 0)
  #   |> playTurn(tag, "first")
  #   |> showGameStatus({tag, opponent}, {[], []}, 0, 0)
  #   |> playTurn(opponent, "second")
  #   |> showGameStatus({tag, opponent}, {[], []}, 0, 1)
  # end

  @doc """
  Given a bgame, a board, a localUserTag and color to play, calls the appropriate
  View functions to play a full turn of the game, so might ask for input or choose between options

  asks the local user indicated for a move, the io.get prompts etc
  """
  def playTurn(:chess, board, localUserTag, color) do
    IO.puts(
      "It is now the turn of #{localUserTag}, please enter your move in the following format (<location> <location> <piececolor> <piecetype>):\n"
    )

    input = IO.gets("")
    i = String.trim(input)
    {:ok, {s_loc, e_loc, playerColor, pieceType}} = parseMove(i)

    case playerColor do
      ^color -> board |> move(s_loc, e_loc, playerColor, pieceType)
      _any -> raise ArgumentError, message: "tried to move another's piece"
    end
  end

  def playTurn(:ur, ur_board, localUserTag, color) do
    IO.puts("It is the turn of #{localUserTag}, of color #{color}. Roll them bones! (press enter to roll them dice)")
    IO.gets("") # so you have to roll the dice

    roll = roll_pyramids_list(4) # rolls four pyramids, returns sum of roll value
    IO.puts("Rolled the following: #{inspect(roll)}")
    IO.puts("You rolled them dice! you rolled a #{roll}!")
    input = IO.gets("Please enter the move coordinates in the following format, <starting location> <ending location> <piececolor>")
    i = String.trim(input)
    {:ok, {s_loc, e_loc, playerColor}} = parse_ur_move(i)
  end

  @doc """
  returns an integer: choosing randomly between either 0 or 1
  # the idea is to allow levels of sophistication, so this might best be
  # represented by atoms summing up the behavior in the future
  """
  def randomLevel() do
    Enum.random(0..1)
  end

  @doc """
  Returns a GameRunner struct of a default configuration given the playertypes and tags
  """
  def createGame(first_playertype, second_playertype, tag, opp_tag) do
    %GameRunner{
      board: Chessboard.createBoard(),
      turn: :orange,
      first: %Player{type: first_playertype, color: :orange, tag: tag, lvl: 1},
      second: %Player{type: second_playertype, color: :blue, tag: opp_tag, lvl: 1},
      status: :in_progress,
      history: [],
      resolution: nil,
      reason: nil
    }
  end

  # returns an outcome in the format [{player1, player2}, resolution]
  #   where if player1 wins, resolution is :win, if player2 wins, resolution is :loss,
  #   if drawn, resolution is :drawn
  # possible @resolutions: [win, loss, drawn]
  # possible playTypes: [human, cpu, online, human_vs_cpu]

  @doc """
  Starts a game given a list of two player_tags and a playType (:vs, :online, :cpu).
  :vs = [:human v :human]
  :cpu = [:human v :computer]
  :pcu = [:computer v :human]
  :simulation = [:computer v :computer]
  :trolled = [:online v :computer]
  :trolling= [:computer v :online]
  :online = [:online v :online]
  :playnet = [:online v :human]
  :netplay = [:human v :online]

  First, the appropriate stuff is displayed on the screen via the View interface,
  then the players make their moves. How input is taken/generated depends
  on what sort of players there are in the game.
  There are human, cpu, and online players.
  CPUs generate their moves in the moment, while humans make the computer prompt for input, which
  the human gives via cli or via mouseclicks or button-presses depending on the view
  Online will just have to wait.

  Returns an outcome (a struct I suppose giving the info in the game)
  """
  def runGame([player1, player2], playType, bgame) when playType |> is_atom(),
    do: runGame([player1, player2], [playType, playType], bgame)

  def runGame([player1, player2] = _both_players, [first_pt, second_pt] = _playTypeList, bgame) do
    # "lvl: randomLevel()" should be subbed in for "lvl: 1" if that is the desired behavior
    # That is, the level of of the player of the first and second should be defined here, then given to the GameRunner
    %GameRunner{
      board: modulizeGame(bgame).createBoard(),
      bgame: bgame,
      turn: :orange,
      first: %Player{type: first_pt, color: :orange, tag: player1, lvl: 1},
      second: %Player{type: second_pt, color: :blue, tag: player2, lvl: 1},
      status: :in_progress,
      history: [],
      resolution: nil,
      reason: nil
    }
    |> gameStart()
    # PUT THE STARTING GAME IO STUFF HERE , LIKE FOR LOGS THIS WILL BE WHERE IT GOES
    # takeTurns is the main loop of the game
    |> takeTurns()
    # the take turns loop has ended, so the game cannot continue, now we must figure out who won and then why
    |> findResolution()
    # once we find the resolution, we can find the _reason_ the game ended
    # honestly this seems backwards, the board tells us when the game is over, it already knows why. So why would we be
    # asking the board something it's already had the opportunity to provide?
    |> findEndingReason()
    |> convertToOutcome()

    # %Outcome{players: [game.first, game.second], resolution: findResolution(game.board), reason: findEndingReason(game.board)}
  end

  # Outcome%{players: [player1, player2], resolution: :loss, reason: :checkmate}
  # Outcome%{players: [player1, player2], resolution: :drawn, reason: :stalemate}
  # Outcome%{players: [player1, player2], resolution: :win, reason: :resignation}

  @doc """
  Given a GameRunner, passes off finding a resolution to GameRunner, raising an error if not won, lost or drawn
  """
  def findResolution(game) do
    cond do
      GameRunner.isLost(game, game.turn) ->
        %GameRunner{game | resolution: :win}

      GameRunner.isWon(game, game.turn) ->
        %GameRunner{game | resolution: :loss}

      GameRunner.isDrawn(game, game.turn) ->
        %GameRunner{game | resolution: :drawn}

      true ->
        raise GameError,
          message: "Game is not a draw, win or loss, cannot find resolution #{inspect(game)}}"
    end
  end

  @doc """
  Given a GameRunner, based on the state of the board and the resolution recorded, returns GameRunner with the ending reason set,
  and if the ending reason is not a stalemate, insufficient material, fifty move rep,  agreed, checkmate, or resignation,
  raise an error
  """
  def findEndingReason(game) do
    reason =
      cond do
        game.resolution == :drawn ->
          cond do
            Chessboard.isStalemate(game.board, game.turn) ->
              :stalemate

            Chessboard.isInsufficientMaterial(game.board) ->
              :insufficient_material

            Chessboard.isFiftyMoveRepitition(game.board, game.turn) ->
              :fifty_move_repitition

            true ->
              :agreed
          end

        game.resolution == :loss or game.resolution == :win ->
          if Chessboard.isCheckmate(game.board, game.turn) do
            :checkmate
          else
            :resignation
          end

        true ->
          :other
      end

    case reason do
      :other ->
        raise GameError,
          message: "Game is not a draw, win or loss, cannot find ending reason #{inspect(game)}"

      _any ->
        true
    end

    %GameRunner{game | reason: reason}
  end

  @doc """
  Given a GameRunner, return an Outcome struct (includes players, resolution and reason, nothing else)
  """
  def convertToOutcome(game) do
    %Outcome{players: [game.first, game.second], resolution: game.resolution, reason: game.reason}
  end

  @doc """
  Given a GameRunner and color, return whether the board in the game is drawn (calls Board function)
  """
  def isDrawn(game, color) do
    Chessboard.isDraw(game.board, color)
  end

  @doc """
  Given a GameRunner and color, return whether the board in the game is won by that color
  """
  def isWon(game, color) do
    Chessboard.isCheckmate(game.board, Chessboard.otherColor(color))
  end

  @doc """
  Given a GameRunner and color, return whether the board in the game is lost by that color
  """
  def isLost(game, color) do
    Chessboard.isCheckmate(game.board, color)
  end

  @doc """
  Given a game struct, make sure the initial startGame text is displayed,
  and returns game, depending on the mode, could ask for input here etc
  """
  def gameStart(game) do
    View.CLI.displays(:game_intro, game.first, game.second, :normal)
    game
  end

  @doc """
  Too large of a function !! TODO

  Given a GameRunner, initiates the turn-taking phase of the game. The main loop!
  Whomever's turn it is, that player will be prompted (by their color)
  to make a move. First there will be a check to see if the game is over.
  It shouldn't be, but say someone gave you a position and asked to evaluate it
  You'd have to be able to identify whether it's playable or not.
  If it's over we should raise an error or a fuss somehow. Let's do that now.
  OK, but if the game can still be played, play a turn.
  """
  def takeTurns(game) do
    case game.first.type do
      :computer -> View.CLI.showGameBoardAs(game.bgame, game.board, game.first.color)
      _other -> View.CLI.showGameBoardAs(game.bgame, game.board, game.turn)
    end

    if GameRunner.isOver(game) do
      # game is over, so we can stop taking turns
      %{game | status: :ended}
    else
      case game.turn do
        :orange -> playTurn(game, game.first)
        :blue -> playTurn(game, game.second)
      end
      |> takeTurns()
    end
  end

  @doc """
  given a GameRunner (including board, turn and history), return when the board state ends the game or there is thrice repitition
  """
  def isOver(game) do
    case game.bgame do
      :chess -> Chessboard.isOver(game.board, game.turn) or
        isThreeFoldRepitition(game.board, game.turn, game.history)
      :ur -> UrBoard.isOver(game.board)
      # default to chess if bgame is unset
      :unset -> Chessboard.isOver(game.board, game.turn) or isThreeFoldRepitition(game.board, game.turn, game.history)
    end
  end

  @doc """
  Given a board, the color/player to_play and history, return whether there is a threefold repitition
  """
  def isThreeFoldRepitition(board, to_play, history) do
    placements = board.placements
    first_castleable = board.first_castleable
    second_castleable = board.second_castleable
    position = {to_play, first_castleable, second_castleable, placements}

    historyContainsTwoEqualPositions(history, position)
  end

  @doc """
  Given a list of history and a position, if the position is in the history list twice return true, else false
  A position tuple is {color, first_castleable, second_castleable, placements} because different castle status is a different posn
  """
  def historyContainsTwoEqualPositions(history_list, position_tuple) do
    case Enum.member?(history_list, position_tuple) do
      true ->
        new_h = List.delete(history_list, position_tuple)

        case Enum.member?(new_h, position_tuple) do
          true -> true
          false -> false
        end

      false ->
        false
    end
  end

  @doc """
  Given a GameRunner and a Player, assigns what to do in the game loop as determined by the type of player,
  assigning human turns to vs and human, cpu turns to computer and cpu, otherwise raising an error,
  and then appending the GameRunner to the History.

  (recursively deals with a game, and a color, and maybe a player,
  returning at the end of it a game that has taken that turn,
  asked for input when necessary, or calculated moves)
  """
  def playTurn(game, player) do
    case player.type do
      :vs -> playHumanTurn(game, player, game.bgame)
      :human -> playHumanTurn(game, player, game.bgame)
      :computer -> playCPUTurn(game, player.lvl, game.bgame)
      :cpu -> playCPUTurn(game, player.lvl, game.bgame)
      _ -> raise GameError, message: "Invalid player type #{inspect(player)}"
    end
    |> appendToHistory(game)
  end

  @doc """
  Given a new_game and an old_game, appends the old_game to the new_game
  """
  def appendToHistory(new_game, old_game) do
    %{new_game | history: [old_game | new_game.history]}
  end

  @doc """
  given a board and turn to help parse, asks the user for input and returns a move answer
  that parses correctly, giving them two tries and then erroring out
  """
  def askAndCorrectlyParse(board, turn) do
    move1_raw = View.CLI.ask(:game_turn)
    # parse the move
    {:ok, parsed} =
      case Parser.parseMoveCompare(move1_raw, board, turn) do
        {:ok, parsed1} ->
          {:ok, parsed1}

        {:error, e} ->
          View.CLI.displayError(:move_input_error, e)
          move2_raw = View.CLI.ask(:game_turn)

          case Parser.parseMoveCompare(move2_raw, board, turn) do
            {:ok, parsed2} -> {:ok, parsed2}
            {:error, e} -> raise ArgumentError, message: "entered incorrect input #{e}"
          end
      end

    parsed
  end

  @doc """
  given a game struct, a turn (color), and a player
  (type, so like :human etc)
  plays one human turn, displaying the gameboard so the human player can make a move, validating the move, then
  making the move or asking for another move, if getting bad input, resigning the player
    # prompt the player for a move
    # validate the move
    # if valid, make the move
    # if invalid, prompt the player again
    # if invalid again, the player resigns

  TODO:
    # if the player resigns, end the game
    # if the player times out, end the game as a timeout loss
  """
  def playHumanTurn(game, player, :chess) do
    turn = game.turn
    # View.CLI.displays(:game_board, game.board |> Chessboard.printBoard(), turn)
    View.CLI.displays(:turn_intro, turn, player)

    # play a turn
    {start_loc, end_loc, type_at_loc, promote_to} =  askAndCorrectlyParse(game.board, game.turn)

    # validate the move
    valid = Referee.validateMove(game.board, start_loc, end_loc, turn, type_at_loc, promote_to)
    # if valid, make the move
    if valid do
      # new_board = Chessboard.makeMove(game.board, move1)
      {:ok, new_board} = Chessboard.move(game.board, start_loc, end_loc, turn, type_at_loc, promote_to)
      %{game | board: new_board, turn: nextTurn(game.turn)}
    else
      {start_loc2, end_loc2, type_at_loc2, promote_to} = askAndCorrectlyParse(game.board, game.turn)

      valid_two = Referee.validateMove(game.board, start_loc2, end_loc2, turn, type_at_loc2, promote_to)

      # if invalid again, the player resigns
      if valid_two do
        # new_board = Chessboard.makeMove(game.board, move2)
        {:ok, new_board} = Chessboard.move(game.board, start_loc2, end_loc2, turn, type_at_loc2, promote_to)
        %{game | board: new_board, turn: nextTurn(game.turn)}
      else
        raise GameError, message: "Player resigned via bad input"
      end
    end
  end


  def playHumanTurn(game, player, :ur) do
    turn = game.turn

    View.CLI.displays(:turn_intro, turn, player)

    #play a turn
    # show the player they need to roll the dice
    View.CLI.promptForRollOfDice(:ur, 4, "It is the turn of #{player.tag}, of color #{turn}.")

    #
    roll = UrBoard.roll_pyramids_list(4)

    View.CLI.displayRoll(roll)

    int_roll = roll |> Enum.sum()

    {:ok, new_board} = case UrBoard.is_there_a_move_available(game.board, int_roll, game.turn) do
      true ->
        {:ok, {start_loc, end_loc, turn}} = View.CLI.promptForUrMove(game, int_roll) |> View.CLI.parse_ur_move()
        valid = Referee.validateUrMove(game.board, start_loc, end_loc, turn)

        if valid do
          UrBoard.move(game.board, start_loc, end_loc, turn)
        else
          raise GameError, message: "Player resigned via bad input"
        end
      false ->
        View.CLI.promptForNoMove(int_roll)
        {:ok, game.board}
    end

    %{game | board: new_board, turn: nextTurn(game.turn)}
  end


  # input = IO.gets("Please enter the move coordinates in the following format, <starting location> <ending location> <piececolor>")
  # i = String.trim(input)
  # {:ok, {s_loc, e_loc, playerColor}} = parse_ur_move(i)

  @doc """
  Given a game and an Integer cpu level (one, two, three, etc),
  return a game with the the move selected according to the level
  """
  def playCPUTurn(game, cpu_level, :chess) when game |> is_struct() and cpu_level |> is_integer() do
    choose_atom = cpu_level_to_choose_atom(cpu_level)
    {start_loc, end_loc, promote_to} = choose_move_from_possible(game, choose_atom)
    apply_move_to_game(game, start_loc, end_loc, promote_to)
  end

  @doc """
  Given a cpu_level (integer from 0 to ?) return the atom representing what function
  to use to pick a move from the list of possible moves
  """
  def cpu_level_to_choose_atom(0), do: :first
  def cpu_level_to_choose_atom(1), do: :random
  def cpu_level_to_choose_atom(2), do: :evaluate_simple

  @doc """
  Given an atom indicating how to choose from the possible moves,
  return a function picking from the list for the desired move
  """
  def choose_atom_to_function(:first), do: &List.first/1
  def choose_atom_to_function(:random), do: &Enum.random/1
  def choose_atom_to_function(:evaluate_simple), do: &evaluate_best/3


  @doc """
  Given a game, a start_loc, end_loc, promote_to (all the stuff you need for a move),
  return a game with a board with the move applied and the turn cycled (and any other game transforms)
  """
  def apply_move_to_game(game, start_loc, end_loc, promote_to) do
    turn = game.turn
    {^turn, piece_type} = Chessboard.get_at(game.board.placements, start_loc)

    {:ok, new_board} = Chessboard.move(game.board, start_loc, end_loc, game.turn, piece_type, promote_to)
    %{game | board: new_board, turn: nextTurn(turn)}
  end

  @doc """
  Given a game and an atom indicating how to choose from the possible moves,
  return a thruple of start_loc, end_loc and promote_to using the strategy
  indicated by the atom
  """
  def choose_move_from_possible(game, :evaluate_simple) do
    choose_fn = choose_atom_to_function(:evaluate_simple)
    case possible_moves_of_color(game.board, game.turn) |> choose_fn.(game, :minimax) do
      {start_loc, end_loc} -> {start_loc, end_loc, :nopromote}
      {_start_loc, _end_loc, _promote_to} = chosen -> chosen
    end
  end

  def choose_move_from_possible(game, choose_atom) do
    choose_fn = choose_atom_to_function(choose_atom)
    case possible_moves_of_color(game.board, game.turn) |> choose_fn.() do
      {start_loc, end_loc} -> {start_loc, end_loc, :nopromote}
      {_start_loc, _end_loc, _promote_to} = chosen -> chosen
    end
  end

  @piece_values %{pawn: 100, knight: 295, bishop: 300, rook: 500, queen: 900, king: 0}

  defmodule ListZipper do
    @moduledoc """
    Module for the ListZipper data structure, If a list is a book,
    a zipped list is a book with a bookmark in it. So previous traverse, current element,
    and next_to_traverse are stored.
    """

    def create(list), do: %{previous: [], remaining: list}

    def forward(%{remaining: []} = zippedList), do: zippedList

    def forward(%{previous: previous, remaining: [remaining_head | remaining_tail]}) do
      %{previous: [remaining_head | previous], remaining: remaining_tail}
    end

    def back(%{previous: []} = zippedList), do: zippedList

    def back(%{previous: [previous_head | previous_tail], remaining: remaining}) do
      %{previous: previous_tail, remaining: [previous_head | remaining]}
    end

    def current(%{remaining: []}), do: nil

    def current(%{remaining: [current | _tail]}), do: current
  end

  # def evaluate_best(list, game) do
    # this is the implementation that is based on current turn onlys

  #   current_turn_eval = count_material(game.board.placements, game.turn)
  #   opponent_eval = count_material(game.board.placements, Chessboard.otherColor(game.turn))

  #   current_turn_eval - opponent_eval
  # end

  @limit 5

  @doc """
  Given a list of possible moves {start_loc, end_loc, possible_moves} and a gamerunner struct,
  return the best possible move according to minimax
  """
  def evaluate_best(list, game, :minimax) when list |> is_list and game |> is_struct do
    zipper = list
    |> ListZipper.create()

    to_play = game.turn
    depth = 1

    best_eval = recursive_best_move(to_play, depth, @limit, game)

    IO.puts(best_eval, label: :best_eval)
    best_eval

    # huh, a hash tree structure has logarithmic value lookups, so if
    # i need a hash map for instance, might be the way
    # orange_eval = count_material(game.board.placements, :orange)
    # blue_eval = count_material(game.board.placements, :blue)
    # evaluation = orange_eval - blue_eval
    # perspective = case game.turn do
    #   :orange -> 1
    #   :blue -> -1
    # end

    # evaluation * perspective
  end

  @doc """
  Given an int returns true if even
  """
  def even(int) when int |> is_integer do
    rem(int, 2) != 1
  end

  @doc """
  Given a color (to_play), depth (int), limit (int), and game (struct), take the possible moves on the board,
  (using alpha beta, based on evenness?) show on cli the possible moves, then set the move score for each and return
  the best possible move (the one with the highest move_score)
  """
  def recursive_best_move(to_play, depth, limit, game) do
    # todo finish this best moves
    possible_moves = Chessboard.possible_moves_of_color(game.board, to_play)
    _alpha_beta = even(depth) # so on even depths, alpha_beta is true, odd false

    possible_moves
    |> Enum.map(fn x -> x |> Enum.into(%{}) end)
    |> Enum.map(fn move -> set_move_score(move, to_play, depth, limit, game) end)
    |> Enum.sort()
    |> Enum.reverse()
    |> List.first()
  end

  @doc """
  returns score o this board
  Given the board, and the color to play, counts the material and returns the count of material multiplied by who is next
  to play, so orange wants higher orange material, blue wants higher blue material
  """
  def score_board(move_ish_board, to_play) do
    orange_eval = count_material(move_ish_board.placements, :orange)
    blue_eval = count_material(move_ish_board.placements, :blue)
    evaluation = orange_eval - blue_eval
    perspective = case to_play do
      :orange -> 1
      :blue -> -1
    end

    evaluation * perspective
  end

  # minimax
  # -Check if game has reached a terminal state and return a value depending on the outcome
  # -Generate all available moves (spots on the board)
  # -Call the minimax function on each available move recursively to reach a terminal state
  # -Evaluate collection of scored moves
  # -Return optimal move


  @doc """
  Given a move, a to_play, depth, limit, and board, tries the move and returns a tuple of move and score
  if depth is more than limit, passes off to helper function decide_this_ply to evaluate the score
  """
  def set_move_score(move, to_play, depth, limit, board) do
    if depth >= limit do
      # end o it
      {move, Chessboard.try_move!(board, move) |> score_board(to_play)}

      # %{move | :score => !move(board, move) |> score_board(to_play)}
    else
      # depth < limit
      decide_this_ply(board, move, to_play, depth, limit)
    end
  end

  @doc """
  Given a bunch of stuff, a recursive function helper that
  calls recursive_best_move with a higher depth and adjusts scores
  """
  def decide_this_ply(board, move, to_play, depth, limit) do
    next_board = Chessboard.makeMove(board, move)
    opponent = Chessboard.otherColor(to_play)
    # recursion here
    next_ply_best_move = recursive_best_move(opponent, depth + 1, limit, next_board)

    alpha_beta = even(depth) # if odd, then it's the other players turn
    case next_ply_best_move do
      any when any |> is_integer -> # it's not [] is it?
        if alpha_beta do
          # the eval player's turn
          %{move | score: move.score + score_board(opponent, next_board)}
        else
          # other player's turn
          %{move | score: move.score - (score_board(opponent, next_board))}
        end
      any_other ->
        # this shouldn't happen?
        # TODO fixme if shouldn't happen, raise error if not an integer, malformed recursive output ?? or just a base case
        move
    end
  end

  @doc """
  Given placements and a color,
  returns the value of the material of that color on the placements by adding them up
  """
  def count_material(placements, turn_color) do
    # list: {location, {color, type}}
    Chessboard.fetch_locations(placements, turn_color)
    |> Enum.map(fn
      {location, {^turn_color, type}} -> @piece_values[type]
    end)
    |> Enum.sum()
  end

  @big_number 100_000_000_000
  @negative_big_number -1 * @big_number

  @doc """
  given a depth and ... return a number representing the value
  found by the search
  {loc, {color, type}}{loc, {color, type}}

  This presumably uses alpha beta pruning
  """
  def search(game, depth, alpha, beta) do
    if depth == 0 do
      recursive_best_move(game.first, depth, 1, game)
      # evaluate_best_move(list, game)
    else
      possible_moves = Chessboard.possible_moves_of_color(game.board, game.turn)
      # {loc, placement = {color, type}}

      with {:no_moves, true} <- {:no_moves, possible_moves == []}, true <- Chessboard.isCheck() do
        @negative_big_number # checkmate bad
      else
        {:is_check, false} ->
          0 # stalemate ok
        {:no_moves, false} ->
          # move eval

          # best_evaluation = @negative_big_number
          best = pick_best_alpha_beta_pruning(game, possible_moves, depth, alpha, beta)
      end
    end
  end

  @doc """
  Given a list of possible moves, prune the bad ones and return the value represented by search, only possible moves here
  """
  def pick_best_alpha_beta_pruning(game, possible_moves, depth, alpha, beta) do

    beta_is_best = false

    # this strays from elixir scoping todo:
    for move <- possible_moves do
      # show me the move
      IO.puts(move)
      # IS IT?       move = loc, color, type
      {start_loc, end_loc, player_color, piece_type} = move
      # pull newboard out of move
      piece_type = Chessboard.get_at(game.board.placements, start_loc)
      {:ok, new_board} = Chessboard.move(game.board, start_loc, end_loc, player_color, piece_type)
      # evaluation is recursive search with 1 less depth and negative beta and alpha times negative 1 ???? todo

      evaluation = search(game, depth - 1, -beta, -alpha) * -1
      # bestEvaluation = max(evaluation, bestEvaluation)
      if evaluation >= beta do

        #TODO make break for loop to alpha beta prune properly
        # (sic) break return beta # todo remake for loop

        # move too good, opponent will avoid this position
        beta_is_best = true
      else
        # move not too good, opponent will not avoid this position

        alpha = max(alpha, evaluation)
      end
    end

    if beta_is_best do
      beta
    else
      alpha
    end
  end

  # @doc """
  # Given a list of moves, reorders them to place the good moves first
  # """
  # def order_moves(list_o_moves) do
  #   for {start_loc, end_loc, {color, type}} = move <- list_o_moves do
  #     move_score_guess = 0
  #     move_piece_type = type
  #     capture_piece_type = grab_piece_at(end_loc) # todo or refactor

  #     # prioritize capturing opps best pieces with our worst pieces
  #     if (capture_piece_type) != {:error, "no piece"} do
  #       move_score_guess = 10 * @piece_values[capture_piece_type] - @piece_values[move_piece_type]
  #     end # trying to sideeffect todo

  #     # promoting a pawn is probably good
  #     if (promote_to != :nopromote) do
  #       move_score_guess = move_score_guess + @piece_values[promote_to]
  #     end # trying to sideeffect todo

  #     # moving stuff to a square threatened by an enemy pawn should be deemphasized
  #     if other_player_threatens_with_pawn(end_loc) do
  #       move_score_guess = move_score_guess - @piece_values[move_piece_type]
  #     end

  #   end
  # end

  # @doc """
  # TODO stub
  # """
  # def other_player_threatens_with_pawn(end_loc) do
  #   false
  # end

  # @doc """
  # Given an end_loc, returns
  # """
  # def grab_piece_at(end_loc) do

  # end

  def playTurnOnline(_game) do
    # prompt the player for a move
    # validate the move
    # if valid, make the move
    # if invalid, prompt the player again

    # if the player resigns, end the game
    # if the player times out, end the game

    # if the player disconnects, end the game
    # if the player is disconnected, end the game
    # if the player is disconnected, end the game
  end

  def playTurnOnline(_game, _turn, _player) do
    # prompt the player for a move
    # validate the move
    # if valid, make the move
    # if invalid, prompt the player again

    # if the player resigns, end the game
    # if the player times out, end the game

    # if the player disconnects, end the game
    # if the player is disconnected, end the game
    # if the player is disconnected, end the game
    {:error, :unsupported}
  end

  def nextTurn(:blue), do: :orange
  def nextTurn(:orange), do: :blue
  ##### Online Game Functions #####

  def finish(game), do: %GameRunner{game | status: :ended}
end
