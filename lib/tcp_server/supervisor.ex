defmodule KV.Supervisor do
  @moduledoc """
  All about the Supervisor from Tutorial
  """
  use Supervisor

  def start_link(opts) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {MyRegistry, name: MyRegistry},
      {DynamicSupervisor, name: MyBucketSupervisor, strategy: :one_for_one}
    ]

    Supervisor.init(children, strategy: :one_for_all)
  end
end
