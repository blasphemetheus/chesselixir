defmodule EchoServer do
  @moduledoc """
  Tutorial EchoServer
  """
  require Logger
  # tcp servers:
  # - listen to a port until port is available the server gets hold of the socket
  # - waits for a client connection on that port and accepts it
  # - reads the client request and writes a response back

  def accept(port) do
    # the options below:
    # 1. :binary - receives data as binaries (not lists)
    # 2. packet: :line - receives data line by line
    # 3. active: false - blocks on `:gen_tcp.recv/2` until data is avail
    # 4 reuseaadr: true - allows us to reuse the address if the listener crashes

    {:ok, socket} =
      :gen_tcp.listen(port, [:binary, packet: :line, active: false, reuseaddr: true])

    Logger.info("Acception Connections on port #{port}")
    loop_acceptor(socket)
  end

  defp loop_acceptor(socket) do
    {:ok, client} = :gen_tcp.accept(socket)
    serve(client)
    loop_acceptor(socket)
  end

  defp serve(socket) do
    socket
    |> read_line()
    |> write_line(socket)

    serve(socket)
  end

  defp read_line(socket) do
    {:ok, data} = :gen_tcp.recv(socket, 0)
    data
  end

  defp write_line(line, socket) do
    :gen_tcp.send(socket, line)
  end
end
