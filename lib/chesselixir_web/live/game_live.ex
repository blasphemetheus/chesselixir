defmodule Chesselixir.GameLive do
  use ChesselixirWeb, :live_view
  alias ChesselixirWeb.Chess.{GameServer, Engine}

  @impl true
  def mount(%{"id" => id}, _session, socket) do
    {:ok, _} = GameServer.ensure_started(id)
    board = GameServer.board(id)
    {:ok, assign(socket, id: id, board: board, sel: nil, error: nil)}
  end

  @impl true
  def handle_event("select", %{"x" => x, "y" => y}, socket) do
    {x, _} = Integer.parse(x)
    {y, _} = Integer.parse(y)

    case socket.assigns.sel do
      nil ->
        {:noreply, assign(socket, sel: {x, y}, error: nil)}

      {sx, sy} ->
        case GameServer.move(socket.assigns.id, {sx, sy}, {x, y}) do
          :ok ->
            {:noreply,
             socket
             |> assign(board: GameServer.board(socket.assigns.id), sel: nil, error: nil)}

          {:error, reason} ->
            {:noreply, assign(socket, error: reason, sel: nil)}
        end
    end
  end

  @impl true
  def render(assigns) do
    ~H"""
    <div class="game-wrap">
      <div class="board">
        <%= for {row, r_index} <- Enum.with_index(@board, 0) do %>
          <%= for {piece, c_index} <- Enum.with_index(row, 0) do %>
            <% # convert indices: our board is top row index 0 => rank 8 %>
            <% x = c_index + 1 %>
            <% y = 8 - r_index %>
            <button
              phx-click="select"
              phx-value-x={x}
              phx-value-y={y}
              class={"sq " <> square_class(x, y, @sel)}
              title={"#{x},#{y}"}
            >
              <%= piece_to_glyph(piece) %>
            </button>
          <% end %>
        <% end %>
      </div>

      <div class="hud">
        <%= if @error do %>
          <p class="error"><%= @error %></p>
        <% end %>
        <p>Selected: <%= inspect(@sel) %></p>
        <p>Game ID: <%= @id %></p>
      </div>
    </div>
    """
  end

  defp square_class(x, y, sel) do
    base = if rem(x + y, 2) == 0, do: "light", else: "dark"
    if sel == {x, y}, do: base <> " selected", else: base
  end

  # simple glyphs; replace with images if you like
  defp piece_to_glyph(nil), do: ""
  defp piece_to_glyph(:wP), do: "♙"
  defp piece_to_glyph(:wN), do: "♘"
  defp piece_to_glyph(:wB), do: "♗"
  defp piece_to_glyph(:wR), do: "♖"
  defp piece_to_glyph(:wQ), do: "♕"
  defp piece_to_glyph(:wK), do: "♔"
  defp piece_to_glyph(:bP), do: "♟︎"
  defp piece_to_glyph(:bN), do: "♞"
  defp piece_to_glyph(:bB), do: "♝"
  defp piece_to_glyph(:bR), do: "♜"
  defp piece_to_glyph(:bQ), do: "♛"
  defp piece_to_glyph(:bK), do: "♚"
end
