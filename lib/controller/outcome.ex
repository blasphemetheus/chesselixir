defmodule Outcome do
  @moduledoc """
  All about Outcomes
  """
  defstruct players: [], resolution: :win, reason: :checkmate, games: [], score: [0, 0]
end
