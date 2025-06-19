defmodule Ridez.Rides.Ride.Calculations.TakenSeatCounts do
  @moduledoc """
  Calculates the count of taken seats by seat type for a ride.

  This calculation transforms the existing `:taken_seats` list aggregate into a more
  useful count map format. Instead of returning a list like `[:driver, :backseat, :backseat]`,
  it returns a map showing how many seats of each type are taken: `%{"driver" => 1, "backseat" => 2}`.

  ## Why this is needed

  The raw list of taken seats is useful for some operations, but for seat availability
  calculations, we need to know the count of taken seats per type. This calculation
  provides that foundation data that other calculations can build upon.

  ## Usage

  Load this calculation to get taken seat counts by type:

      ride = Ash.load!(ride, [:taken_seat_counts])
      ride.taken_seat_counts
      # => %{"driver" => 1, "backseat" => 2}

  ## Example

      iex> # Given a ride with seats taken
      iex> ride = %{taken_seats: [:driver, :backseat, :backseat]}
      iex> # The calculation would return:
      iex> %{"driver" => 1, "backseat" => 2}
      
  This calculation is used as a building block for other seat-related calculations
  like `:available_seat_counts` and `:occupied_seat_types`.
  """
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    [:taken_seats]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Convert list of seats like [:driver, :backseat, :backseat] 
      # to map like %{"driver" => 1, "backseat" => 2}
      record.taken_seats
      |> Enum.frequencies()
      |> Enum.into(%{}, fn {seat, count} -> {to_string(seat), count} end)
    end)
  end
end