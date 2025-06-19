defmodule Ridez.Rides.Ride.Calculations.AvailableSeatTypes do
  @moduledoc """
  Calculates which seat types are available for booking on a ride.

  This calculation returns a list of seat types (as atoms) that still have
  available capacity. It filters seat types based on the `:available_seat_counts`
  calculation, including only those with a count greater than zero.

  ## Why this is needed

  This is the primary calculation requested for the seat availability feature.
  It provides a simple, clean answer to "what seat types can passengers book?"
  without requiring clients to parse count maps or do their own filtering logic.

  This calculation is perfect for:
  - UI dropdowns showing available seat options
  - API responses listing bookable seat types
  - Business logic that needs to check if specific seat types are available

  ## Usage

  Load this calculation to get available seat types:

      ride = Ash.load!(ride, [:available_seat_types])
      ride.available_seat_types
      # => [:backseat, :window]

  Use in queries to find rides with available seats:

      rides_with_driver_seats = MyDomain.list_rides!(
        filter: [available_seat_types: [contains: :driver]]
      )

  ## Example

      iex> # Given a ride with mixed availability
      iex> ride = %{
      iex>   available_seat_counts: %{"driver" => 0, "backseat" => 2, "window" => 1}
      iex> }
      iex> # The calculation would return:
      iex> [:backseat, :window]
      
  The result excludes `:driver` because it has 0 available seats, but includes
  the other types that still have capacity.
  """
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    [:available_seat_counts]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Get available seat counts: %{"driver" => 0, "backseat" => 1}
      # Return list of seat types where count > 0: [:backseat]
      (record.available_seat_counts || %{})
      |> Enum.filter(fn {_seat_type, count} -> count > 0 end)
      |> Enum.map(fn {seat_type, _count} -> String.to_atom(seat_type) end)
      |> Enum.sort()
    end)
  end
end