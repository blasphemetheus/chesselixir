defmodule CLIIntro do
  @moduledoc """
  Documentation for `CLI_Intro`. If not passed in as arguments to the main fn, the necessary info
  is gathered from the user via IO.gets and IO.puts to start chess in a context (tournament, match, game) and
  a playType (online, vs, cpu).
  """
  @context_inputs ["TOURNAMENT", "T", "MATCH", "M", "GAME", "G"]
  @playtype_inputs ["ONLINE", "O", "VS", "V", "CPU", "C"]
  @game_inputs ["CHESS", "C", "UR", "U"]

  @asks %{
    tag: "\nHello!. What is your player tag?\n",
    which_game: "What game are you playing today?\n",
    play_type:
      "Let's play.\n\rHow would you like to play it? pick one of (online, vs, cpu)\n",
    opponent_tag: "What is the name of your opponent?\n",
    cpu_level: "What level opponent would you like to play vs?\n",
    context: "What context would you like to play in? (tournament, match, game)\n",
    amount_of_players: "How many players are in the tournament? (1, 2, ... 1000)\n",
    games_per_matchup: "How many games per matchup? (1, 2, ... 8)\n"
  }

  @display_msgs %{
    tournament: "Context chosen: tournament.\n",
    match: "Context chosen: match.\n",
    game: "Context chosen: game.\n",
    online: "You have chosen to play online.\nPlease wait for your opponent to join.\n",
    vs: "You have chosen to play locally versus an opponent.\n",
    cpu: "You have chosen to play locally against the computer.\n",
    try_again: "Invalid input: Please try again.\n"
  }

  def address(tag, postscript \\ "\n") do
    case Enum.random(1..10) do
      1 -> "Hey there #{tag}!"
      2 -> "Greetings Sibling #{tag}."
      3 -> "Howdy #{tag}_"
      4 -> "Suahh #{tag},"
      5 -> "Wuts good #{tag}?"
      6 -> "Oh it's you #{tag}. (Yikes)"
      7 -> "<stares deep into your soul> Hmmb. #{tag}. You have come."
      8 -> "B*tch you're back? Ok. Ok. #{tag} I hope you're happy~"
      9 -> "At Last! Mein Frend #{tag} has returned to us!"
      10 -> "Spare Me Oh Glorious #{tag}!!! Forgive me my sins!!!"
    end <> postscript
  end

  def tagval(tag), do: String.length(tag) > 0 and String.length(tag) < 30
  def gameval(game), do: game in @game_inputs
  def contextval(context), do: context in @context_inputs
  def playtypeval(playType), do: playType in @playtype_inputs
  def cpulevelval(cpulevel), do: String.to_integer(cpulevel) in 1..10
  def amountplayersval(amount_of_players), do: String.to_integer(amount_of_players) in 1..1000
  def gamespermatchupval(games_per_matchup), do: String.to_integer(games_per_matchup) in 1..8

  def types(atom) do
    case atom do
      :tag -> &CLIIntro.tagval/1
      :which_game -> &CLIIntro.gameval/1
      :opponent_tag -> &CLIIntro.tagval/1
      :context -> &CLIIntro.contextval/1
      :play_type -> &CLIIntro.playtypeval/1
      :cpu_level -> &CLIIntro.cpulevelval/1
      :amount_of_players -> &CLIIntro.amountplayersval/1
      :games_per_matchup -> &CLIIntro.gamespermatchupval/1
    end
  end

  @doc """
  Uses maps declared in module to validate various inputs from the user, passing the response and atom to a function
  in the @validate_types map, returns an error tuple if not valid
  """
  def validate(atom, atom_response) when is_atom(atom) do
    valfn = types(atom)

    if valfn.(atom_response) do
      {:ok, atom_response}
    else
      {:error, "Unrecognized #{convert(atom)}: #{atom_response}."}
    end
  end

  @doc """
  displayMsg is a standard way to display messages to the user via command line.
  Every possible message is mapped to a string in the @display_msgs map, and arguments depend on the first argument
  """
  def displayMsg(atom, tag) when is_atom(atom) do
    IO.puts(address(tag) <> @display_msgs[atom])
  end

  def displayMsg(atom) when is_atom(atom) do
    IO.puts(@display_msgs[atom])
  end

  @doc """
  Ask is a standard way to gather input from the user view command line.
  Every possible ask is mapped to a string in the @asks map, and arguments depend on the first argument
  Validation is part of ask, and an invalid response will cause ask to recur once, and then return an error tuple.
  """
  def ask(atom, recur_bool \\ true) when is_atom(atom) do
    atom_response = IO.gets(@asks[atom]) |> String.upcase() |> String.trim()
    IO.puts("")

    case validate(atom, atom_response) do
      {:error, e} ->
        case recur_bool do
          true ->
            IO.puts(e)
            displayMsg(:try_again)
            ask(atom, false)

          false ->
            raise ArgumentError, message: e
        end

      {:ok, _} ->
        unshorten(atom_response)
    end
  end

  @doc """
  Convenience fn for unshortening strings the user inputted to their full form
  """
  def unshorten("T"), do: "TOURNAMENT"
  def unshorten("M"), do: "MATCH"
  def unshorten("G"), do: "GAME"
  def unshorten("O"), do: "ONLINE"
  def unshorten("V"), do: "VS"
  def unshorten("C"), do: "CPU"
  def unshorten("U"), do: "UR"
  def unshorten(string), do: string

  @doc """
  Convenience fn for converting strings to downcased atoms and atoms to upcased strings
  """
  def convert(string) when is_binary(string),
    do: string |> String.downcase() |> String.to_existing_atom()

  def convert(atom) when is_atom(atom), do: Atom.to_string(atom) |> String.upcase()

  @doc """
  The best entry point for new users, gathers the players tag and redirects
  to online, vs, or cpu chess games. your options are "online" "vs" and "cpu"

    iex> welcome()
    "Hello! What is your player tag?\n"
    "online\n"

    iex> welcome()
    "Hello! What is your player tag?\n"
    "vs\n"

    iex> welcome()
    "Hello! What is your player tag?\n"
    "cpu\n"

    ||||||| tournament   |  match |   game    |||||||||||||||||
    ___________________________________________________________
    online| YES          |  YES   |   YES     |              |
    vs    |   YES        | YES    |   YES     |              |
    cpu   |    YES       |  YES   | YES       |              |
    |||||||||||||||||||||||||||||||||||||||||||||||||||||||||||

  """
  def welcome() do
    # input: me -> output: "ME"
    tag_str = ask(:tag)

    game_str = ask(:which_game)
    game = convert(game_str)

    # random greeting on it's own line.
    address(tag_str, " ")
    # input: "t" -> output: "TOURNAMENT"
    context_str = ask(:context)
    context = convert(context_str)

    # input: "TOURNAMENT" -> output: "Context chosen: tournament.\n"
    CLIIntro.displayMsg(context, tag_str)

    address(tag_str, " ")
    # input: "o" -> output: "ONLINE"
    play_type_str = ask(:play_type)
    play_type = convert(play_type_str)

    CLIIntro.displayMsg(play_type, tag_str)

    {tag_str, game, context, play_type}
  end
end
