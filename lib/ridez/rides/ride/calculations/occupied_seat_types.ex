defmodule Ridez.Rides.Ride.Calculations.OccupiedSeatTypes do
  @moduledoc """
  Calculates which seat types currently have passengers on a ride.

  This calculation returns a list of seat types (as atoms) that have at least
  one passenger assigned. It's the complement of `:available_seat_types` - 
  showing which seat types are in use rather than which are available.

  ## Why this is needed

  This calculation is useful for:
  - Analytics and reporting on seat utilization patterns
  - UI components that need to show which areas of a vehicle are occupied
  - Business logic that needs to know if certain seat types are being used
  - Validation that ensures certain seat types (like driver) are occupied

  ## Usage

  Load this calculation to get occupied seat types:

      ride = Ash.load!(ride, [:occupied_seat_types])
      ride.occupied_seat_types
      # => [:driver, :backseat]

  Use in analytics queries:

      rides_with_drivers = MyDomain.list_rides!(
        filter: [occupied_seat_types: [contains: :driver]]
      )

  ## Example

      iex> # Given a ride with some passengers
      iex> ride = %{
      iex>   taken_seat_counts: %{"driver" => 1, "backseat" => 2}
      iex> }
      iex> # The calculation would return:
      iex> [:driver, :backseat]
      
  The result includes any seat type that has a count > 0 in the taken seats,
  regardless of how many passengers are in that seat type.
  """
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    [:taken_seat_counts]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Get taken seat counts: %{"driver" => 1, "backseat" => 2}
      # Return list of seat types that have passengers: [:driver, :backseat]
      (record.taken_seat_counts || %{})
      |> Map.keys()
      |> Enum.map(&String.to_atom/1)
      |> Enum.sort()
    end)
  end
end