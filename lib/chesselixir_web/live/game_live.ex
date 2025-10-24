defmodule ChesselixirWeb.GameLive do
  use ChesselixirWeb, :live_view
  alias Phoenix.PubSub
  alias Chesselixir.{Games}
  alias Chesselixir.Game.{Board, Engine}

  defp topic(id), do: "game:" <> id

  def mount(%{"id" => id}, _session, socket) do
    if connected?(socket), do: PubSub.subscribe(Chesselixir.PubSub, topic(id))
    {:ok, load(assign(socket, id: id, select: nil))}
  end

  defp load(socket) do
    game = Games.get!(socket.assigns.id)
    board = Board.from_fen(game.fen)
    assign(socket, game: game, board: board)
  end

  def handle_event("select", %{"sq" => sq}, %{assigns: %{select: nil}} = s),
    do: {:noreply, assign(s, select: sq)}

  def handle_event("select", %{"sq" => sq}, %{assigns: %{select: from, board: board, id: id}} = s) do
    case Engine.apply_move(board, {from, sq}) do
      {:ok, new_board} ->
        {:ok, game} = Games.apply_move(id, from, sq, new_board)
        PubSub.broadcast(Chesselixir.PubSub, topic(id), {:updated, game.fen})
        {:noreply, assign(s, select: nil, board: new_board, game: game)}

      {:error, _} ->
        {:noreply, assign(s, select: nil)}
    end
  end

  def handle_info({:updated, fen}, s),
    do: {:noreply, assign(s, board: Board.from_fen(fen))}

    def render(assigns) do
      ~H"""
      <div class="board" style="display: grid; grid-template-columns: repeat(8, 50px);">
        <%= for rank <- 8..1 do %>
          <%= for file <- 1..8 do %>
            <% sq = Board.square(file, rank) %>
            <button
              phx-click="select"
              phx-value-sq={sq}
              class={Board.css(file, rank)}
              style="width:50px;height:50px;"
            >
              <%= Board.glyph(@board, sq) %>
            </button>
          <% end %>
        <% end %>
      </div>
      """
    end
end
