defmodule GameError do
  @moduledoc """
  This module defines the GameException exception.
  This exception represents a problem in the game portion of the code, not the stuff
  specific to the implementation of the game (so in board for gchess).
  """

  @doc """
  This exception declaration creates the default message I think
  """
  defexception message: "a GameException has occurred (something wonky with the game)"
end
