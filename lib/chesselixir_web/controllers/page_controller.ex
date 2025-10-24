defmodule ChesselixirWeb.PageController do
  use ChesselixirWeb, :controller

  def home(conn, _params) do
    render(conn, :home)
  end
end
