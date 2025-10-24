defmodule KV.Bucket do
  @moduledoc """
  Tutorial Bucket
  """
  use Agent, restart: :temporary

  @doc """
  start a new bucket
  """
  def start_link(_opts) do
    Agent.start_link(fn -> %{} end)
  end

  @doc """
  get a value from the bucket by key
  """
  def get(bucket, key) do
    Agent.get(bucket, &Map.get(&1, key))
  end

  @doc """
  put the value for the given key in the bucket
  """
  def put(bucket, key, value) do
    # Agent.update(bucket, &Map.put(&1, key, value))
    # client
    Agent.update(bucket, fn state ->
      # server
      Map.put(state, key, value)
    end)

    # client
  end

  @doc """
  deletes key from bucket, returns current val of key if it exists
  """
  def delete(bucket, key) do
    # Agent.get_and_update(bucket, &Map.pop(&1, key))
    Agent.get_and_update(bucket, fn dict ->
      Map.pop(dict, key)
    end)
  end
end
