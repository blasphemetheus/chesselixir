defmodule ChesselixirWeb.LobbyLive do
  use ChesselixirWeb, :live_view
  alias Chesselixir.Games

  def mount(_params, _session, socket) do
    {:ok, assign(socket, creating?: false, code: nil, error: nil)}
  end

  def handle_event("new_game", _params, socket) do
    {:ok, game} = Games.create_game()  # inserts with startpos FEN
    {:noreply, push_navigate(socket, to: ~p"/play/#{game.id}")}
  end

  def handle_event("join", %{"code" => id}, socket) do
    {:noreply, push_navigate(socket, to: ~p"/play/#{id}")}
  end

  def render(assigns) do
    ~H"""
    <h1>Chesselixir</h1>
    <button phx-click="new_game">New Game</button>
    <form phx-submit="join">
      <input name="code" placeholder="Game ID"/>
      <button>Join</button>
    </form>
    <div class="lobby">
      <h1>Welcome to Chesselixir</h1>
      <button phx-click="new">Start New Game</button>
      <form phx-submit="join">
        <input name="code" value={@code} placeholder="Enter game id"/>
        <button>Join</button>
      </form>
    </div>
    """
  end
end
#   def render(assigns) do
#     ~H"""
#     <div class="lobby">
#       <h1>Welcome to Chesselixir</h1>
#       <button phx-click="new">Start New Game</button>
#       <form phx-submit="join">
#         <input name="code" value={@code} placeholder="Enter game id"/>
#         <button>Join</button>
#       </form>
#     </div>
#     """
#   end
