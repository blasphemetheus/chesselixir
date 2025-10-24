defmodule Main do
  @moduledoc """
  The Driver Module
  """
  #import Board
  #import View.CLI
  #import CLIIntro
  import TournamentOrganizer
  alias TournamentOrganizer, as: TO

  @default_play_type :vs
  @default_context :game
  @default_bgame :chess
  @default_tag "_player_"
  @default_opponent "_opponent_"
  @default_games_per_matchup 2
  @default_amount_of_players 4
  #@default_cpu_level 1
  # @input_types [:auto, :input]

  # @dope """
  # :vs = [:human v :human]
  # :cpu = [:human v :computer]
  # :pcu = [:computer v :human]
  # :simulation = [:computer v :computer]
  # :trolled = [:online v :computer]
  # :trolling = [:computer v :online]
  # :online = [:online v :online]
  # :playnet = [:online v :human]
  # :netplay = [:human v :online]
  # """

  # def gchess(argv) do
  # not
  # taking outline from https://www.youtube.com/watch?v=ycpNi701aCs&list=PLqj39LCvnOWaxI87jVkxSdtjG8tlhl7U6&t=75s
  # {glob, target_dir, format} = parse_options(argv)
  # :ok = validate_options(glob, format)
  # filenames = prepare_conversion(glob, target_dir)
  # results = convert_images(filenames, target_dir, format)
  # report_results(results, target_dir)

  # we want this, but if we do this, each fn signature must match the
  # output of the previous fn, which can be unwieldy with error handling
  # So ... we need the `with` macro
  # argv
  # |> parse_options()
  # |> validate_options()
  # |> prepare_conversion()
  # |> convert_images()
  # |> report_results()

  # these is the with construct, downside being the :error, message can be
  # coming from a couple places, so not extremely verbose error msging
  # with {glob, target_dir, format} <- parse_options(argv),
  #  :ok <- validate_options(glob, format),
  #  filenames <- prepare_conversion(glob, target_dir),
  #  results <- convert_image(filenames, taget_dir, format) do
  #    report_results(results, target_dir)
  # else
  #  {:error, message} -> report_error(message)
  # end

  # token approach
  # end

  # pipes : pipelines, high level flow, control the interfaces, dictate the rules
  # with : swiss army knife, nitty gritty low lvl, calling 3rd pary that doesn't fit

  # defmodule Converter.Token do
  # defstruct [:argv, :glob, :target_dir, :format, :filenames, :results]
  # ...
  # @default_format "png"
  # def build(argv) when is_list(argv) do
  #  %__MODULE__{argv: argv, format: @default_format}
  # end
  # @formats ~w(jpg png)
  # def put_format(token, format) when format in @formats do
  #  %__MODULE__{token | format: format}
  # end
  # def put_format(token, "jpeg"), do: put_format(token, "jpg")
  # ...
  # def put_options(token, glob, target_dir, format) do
  #  token = put_format(token, format) # goes first cause might error
  #  %__MODULE__{token | glob: glob, target_dir: target_dir}
  # end

  # design tokens around intended use
  # design around reqs,
  # create tokens using api, write values using api
  # provide convenience fns for common ops,
  # while writing, validate and normalize inputs
  # end

  # could do a plug pipelines, so using modules instead of fns

  # def do_smth(data) do
  #  with  value <- function1(data),
  #    list <- function2(data, value),
  #    map <- function3(list) do
  #      function4(data, map)
  #    end
  # end

  # say i have a compiled file that I run on the cli
  # with arguments, I want to be able to do a couple things with it
  # - play locally vs a human,
  # - play locally vs a cpu,
  # - watch two cpu-s face off (with ability to)
  #    - time increment option (with ability to step in as
  #      one side or the other, so a `pause` and `play`,
  #      and `takeover --color` and `relinquish --color`
  #    - manual step option (with enter for next turn, or timeincrement --1000 for 1 second)
  # - observe a game with no ability to affect it (so subscribe to it)
  # - start a tournament (just of cpus) that you just run (tasks)

  @doc """
  Welcomes a user and asks for their input on what to do nextm
  like a simulated main menu
  """
  def welcome(), do: main()

  @doc """
  Runs the default, auto game between two cpus with randomized moves and returns a winner
  """
  def cpu(), do: main(:auto, @default_tag, :chess, :game, :cpu)

  def simulation(), do: main(:auto, @default_tag, :game, :computer, :computer)

  @doc """
  Lets a user play chess locally, user input accepted for both sides
  """
  def play(), do: main(:auto, @default_tag, :game, :vs)

  @doc """
  Lets a user play chess locally against the computer
  """
  def train(), do: main(:auto, @default_tag, :game, :vs, :cpu)

  @doc """
  Lets a user play chess online vs an opponent (all cpu's for now)
  """
  def matchmaking(), do: main(:auto, @default_tag, :match, :online)

  @doc """
  Runs a cpu tournament
  """
  def tournament(), do: main(:auto, @default_tag, :tournament, :computer)

  @doc """
  Kicks off the running of gchess play of any sort. If you just run main with no arguments, the CLI
  will ask you the details it needs to proceed ie context (tournament, match, game) and playType (online, vs, cpu).
  The tournament context will ask for: amount_of_players in the tournament and how many games_per_matchup there are
  The match context will ask for: how many games_per_matchup there are

  If you run main with the :default argument, it will run the default context and playType,
  but you can also run with with default, context included and more specific defaults will be used.
  """
  ## CONVENIENCE FUNCTIONS FOR RUNNING DEFAULTS
  def main(:auto), do: main(:auto, @default_tag, @default_bgame, @default_context, @default_play_type)
  def main(:auto, context), do: main(:auto, @default_tag, @default_bgame, context, @default_play_type)
  def main(:auto, context, playtype), do: main(:auto, @default_tag, @default_bgame, context, playtype)
  def main(:auto, context, playtype, bgame), do: main(:auto, @default_tag, bgame, context, playtype)

  def main() do
    {tag_str, bgame, context, playType} = CLIIntro.welcome()

    main(:input, tag_str, bgame, context, playType)
  end

  @doc """
  Starts a tournament of the playtype specified, with the input_type specified,
  with your tag as specified
  """
  def main(input_type, _tag_str, bgame, :tournament, playType) do
    amount_of_players =
      case input_type do
        :input -> CLIIntro.ask(:amount_of_players) |> String.to_integer()
        :auto -> @default_amount_of_players
      end

    games_per_matchup =
      case input_type do
        :input -> CLIIntro.ask(:games_per_matchup) |> String.to_integer()
        :auto -> @default_games_per_matchup
      end

    # returns a tournament winner
    winner = TO.runTournament(amount_of_players, games_per_matchup, playType, bgame)
    IO.puts("Tournament Winner: #{inspect(winner)}")
  end


  # Starts a match of the playtype specified, with the input_type specified,
  # with your tag as specified
  def main(input_type, tag_str, bgame, :match, playType) do
    games_per_matchup =
      case input_type do
        :auto -> @default_games_per_matchup
        :input -> CLIIntro.ask(:games_per_matchup) |> String.to_integer()
      end

    opp_tag_str =
      case input_type do
        :auto -> @default_opponent
        :input -> CLIIntro.ask(:opponent) |> String.to_integer()
      end

    # returns a list of game outcomes
    list_of_outcomes = runMatchup([tag_str, opp_tag_str], games_per_matchup, playType, bgame)
    IO.puts("Match Result: #{list_of_outcomes}")
  end

  # Starts a game of the playtype specified, with the input_type specified,
  # with your tag as specified
  def main(input_type, tag_str, bgame, :game, playType) do
    opp_tag_str =
      case input_type do
        :auto -> @default_opponent
        :input -> CLIIntro.ask(:opponent_tag)
      end

    # returns a game outcome

    playTypeList =
      case playType do
        :vs -> [:human, :human]
        :cpu -> [:human, :computer]
        :upc -> [:computer, :human]
        :simulation -> [:computer, :computer]
        :trolled -> [:online, :computer]
        :trolling -> [:computer, :online]
        :online -> [:online, :online]
        :playnet -> [:online, :human]
        :netplay -> [:human, :online]
      end

    outcome = GameRunner.runGame([tag_str, opp_tag_str], playTypeList, bgame)
    IO.puts("Game Outcome: #{inspect(outcome)}")
  end

  def main(:auto, tag_str, bgame, :game, playType, playType2) do
    list =
      case Enum.random(0..2) do
        0 -> [tag_str, @default_opponent]
        1 -> [@default_opponent, tag_str]
        2 -> ["jimbo", "jombo"]
      end

    GameRunner.runGame(list, [playType, playType2], bgame)
  end
end
