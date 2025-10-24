defmodule TCPServer.Application do
  use Application

  # See https://hexdocs.pm/elixir/Application.html
  # for more information on OTP Applications
  @moduledoc false

  @impl true
  def start(_type, _args) do
    port = String.to_integer(System.get_env("PORT") || "4040")
    # List all child processes to be supervised
    children = [
      # starts a worker by calling TCPServer.Worker.start_link(arg)
      # {KVServer.Worker, arg},
      {Task.Supervisor, name: TCPServer.TaskSupervisor},
      Supervisor.child_spec({Task, fn -> TCPServer.accept(port) end}, restart: :permanent)
    ]

    # See https://hexdocs.pm/elixir/Supervisor.html
    # for other strategies and supported options
    opts = [strategy: :one_for_one, name: TCPServer.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
