defmodule MyApp.Chess.GameServer do
  use GenServer
  alias MyApp.Chess.Engine

  ## Public API

  def start_link(game_id) when is_binary(game_id) do
    GenServer.start_link(__MODULE__, %{}, name: via(game_id))
  end

  def ensure_started(game_id) do
    case GenServer.whereis(via(game_id)) do
      nil ->
        DynamicSupervisor.start_child(
          MyApp.GameSupervisor,
          {__MODULE__, game_id}
        )

      pid -> {:ok, pid}
    end
  end

  def get(game_id), do: GenServer.call(via(game_id), :get)
  def board(game_id), do: GenServer.call(via(game_id), :board)
  def move(game_id, from, to), do: GenServer.call(via(game_id), {:move, from, to})

  ## GenServer

  @impl true
  def init(_opts) do
    {:ok, %{state: Engine.new_game()}}
  end

  @impl true
  def handle_call(:get, _from, s), do: {:reply, s, s}
  def handle_call(:board, _from, %{state: st} = s), do: {:reply, Engine.board(st), s}

  def handle_call({:move, from, to}, _from, %{state: st}) do
    case Engine.move(st, from, to) do
      {:ok, st2} -> {:reply, :ok, %{state: st2}}
      {:illegal, reason} -> {:reply, {:error, reason}, %{state: st}}
    end
  end

  ## Helpers

  defp via(game_id), do: {:via, Registry, {MyApp.GameRegistry, "game:" <> game_id}}
end
