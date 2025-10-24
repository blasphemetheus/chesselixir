defmodule LinkedUrLocation do
  @moduledoc """
  taken inspiration from https://gist.github.com/aaruel/3b4cfac8be09f3eec31e8fe7db295834
  """
  defstruct tile: nil, location: nil, next: nil, index: 0

  def new(tile \\ 0, location \\ nil, index \\ 0) do
    %__MODULE__{tile: tile, location: location, index: index}
  end

  def push(
    current = %__MODULE__{next: next, index: index},
    tile,
    location
  ) do
    if next != nil do
      %{current | next: push(next, tile, location)}
    else
      %{current | next: new(tile, location, index + 1)}
    end
  end

  def size(%__MODULE__{next: next, index: index}) do
    case is_empty(next) do
      true -> index + 1
      false -> size(next)
    end
  end

  def head(%__MODULE__{tile: tile, location: location}) do
    {tile, location}
  end

  def tail(%__MODULE__{tile: tile, location: location, next: next}) do
    case is_empty(next) do
      true -> {tile, location}
      false -> tail(next)
    end
  end

  def pop(%__MODULE__{next: next}) do
    next
  end


  def is_empty(%__MODULE__{}) do
    false
  end

  def is_empty(_whatever) do
    true
  end

  def reverse_implementation(list = %__MODULE__{next: next}, index, rev \\ nil) do
    case is_empty(next) do
      true -> %{list | next: rev, index: index}
      false -> reverse_implementation(next, index - 1, %{list | next: rev, index: index})
    end
  end

  def reverse(list = %__MODULE__{}) do
    reverse_implementation(list, size(list) - 1)
  end
end


# orange_path = LinkedUrLocation.new
#     |> LinkedUrLocation.push(:home, {1, 5})
#     |> LinkedUrLocation.push(:eyes, {1, 4})
#     |> LinkedUrLocation.push(:water, {1, 3})
#     |> LinkedUrLocation.push(:eyes, {1, 2})
#     |> LinkedUrLocation.push(:rosette, {1, 1})
#     |> LinkedUrLocation.push(:crystal, {2, 1})
#     |> LinkedUrLocation.push(:water, {2, 2})
#     |> LinkedUrLocation.push(:ice, {2, 3})
#     |> LinkedUrLocation.push(:rosette, {2, 4})
#     |> LinkedUrLocation.push(:water, {2, 5})
#     |> LinkedUrLocation.push(:ice, {2, 6})
#     |> LinkedUrLocation.push(:eyes, {2, 7})
#     |> LinkedUrLocation.push(:water, {2, 8})
#     |> LinkedUrLocation.push(:plasma, {1, 8})
#     |> LinkedUrLocation.push(:rosette, {1, 7})
#     |> LinkedUrLocation.push(:end, {1, 6})


#   blue_path = LinkedUrLocation.new
#     |> LinkedUrLocation.push(:home, {3, 5})
#     |> LinkedUrLocation.push(:eyes, {3, 4})
#     |> LinkedUrLocation.push(:water, {3, 3})
#     |> LinkedUrLocation.push(:eyes, {3, 2})
#     |> LinkedUrLocation.push(:rosette, {3, 1})
#     |> LinkedUrLocation.push(:crystal, {2, 1})
#     |> LinkedUrLocation.push(:water, {2, 2})
#     |> LinkedUrLocation.push(:ice, {2, 3})
#     |> LinkedUrLocation.push(:rosette, {2, 4})
#     |> LinkedUrLocation.push(:water, {2, 5})
#     |> LinkedUrLocation.push(:ice, {2, 6})
#     |> LinkedUrLocation.push(:eyes, {2, 7})
#     |> LinkedUrLocation.push(:water, {2, 8})
#     |> LinkedUrLocation.push(:plasma, {3, 8})
#     |> LinkedUrLocation.push(:rosette, {3, 7})
#     |> LinkedUrLocation.push(:end, {3, 6})

# IO.inspect(orange_path |> LinkedUrLocation.reverse())
