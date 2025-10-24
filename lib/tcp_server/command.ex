defmodule TCPServer.Command do
  @moduledoc """
  Tutorial Command
  """
  #import(Board)
  require(KV)
  require KV.Registry

  @doc ~S"""
  Parses the given `line` into a command

  ## Examples

    iex> TCPServer.Command.parse("MAKE chess\r\n")
    {:ok, {:make, "chess"}}

    iex> TCPServer.Command.parse("MAKE  chess  \r\n")
    {:ok, {:make, "chess"}}

    iex> TCPServer.Command.parse("STARTINGBOARD chess [startboard] white")
    {:ok, {:start_board, "chess", "[startboard]", "white"}}

    iex> TCPServer.Command.parse("GRAB chess board")
    {:ok, {:grab, "chess", "board"}}

    iex> TCPServer.Command.parse("END chess game\r\n")
    {:ok, {:end, "chess", "game"}}

    unknown cmds or those with a wrong number of args get an error

    iex> TCPServer.Command.parse("UNKNOWN chess game")
    {:error, :unknown_command}

    iex> TCPServer.Command.parse("GRAB chess\r\n")
    {:error, :unknown_command}
  """
  def parse(line) do
    case String.split(line) do
      ["MAKE", game] ->
        {:ok, {:make, game}}

      ["GRAB", game, board] ->
        {:ok, {:grab, game, board}}

      ["STARTINGBOARD", game, initial_board, color_to_start] ->
        {:ok, {:start_board, game, initial_board, color_to_start}}

      ["END", game, which_instance] ->
        {:ok, {:end, game, which_instance}}

      _ ->
        {:error, :unknown_command}
    end
  end

  @doc """
  Runs the given command
  """
  def run(command)

  def run({:make, "chess"}) do
    _board = Chessboard.make2DList(8, 8)
    KV.Registry.create(KV.Registry, "chess")
    {:ok, "OK\r\n"}
  end

  def run({:make, other}) do
    "can't make #{other} sir, stick to chess"
  end

  def run({:grab, "chess", "board"}) do
    {:ok, "WHAT's Good Homie"}
  end

  def run({:grab, bucket, key}) do
    lookup(bucket, fn pid ->
      value = KV.Bucket.get(pid, key)
      {:ok, "#{value}\r\nOK\r\n"}
    end)
  end

  def run({:start_board, bucket, key, value}) do
    lookup(bucket, fn pid ->
      KV.Bucket.put(pid, key, value)
      {:ok, "OK\r\n"}
    end)
  end

  def run({:end, bucket, key}) do
    lookup(bucket, fn pid ->
      KV.Bucket.delete(pid, key)
      {:ok, "OK\r\n"}
    end)
  end

  def lookup(bucket, callback) do
    case KV.Registry.lookup(KV.Registry, bucket) do
      {:ok, pid} -> callback.(pid)
      :error -> {:error, :not_found}
    end
  end
end
