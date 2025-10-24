defmodule Player do
  @moduledoc """
  All about Players
  """
  defstruct type: :human, color: :orange, tag: "Player", lvl: 0

  def toggleControl(player) do
    case player.type do
      :cpu -> %Player{type: :human}
      :human -> %Player{type: :cpu}
      _ -> raise "Invalid player type"
    end
  end
end
