defmodule Ridez.Rides.Ride.Calculations.TotalSeatTypes do
  @moduledoc """
  Calculates all seat types available in a ride's configuration.

  This calculation extracts the seat types from the ride's `seats` attribute and returns
  them as a sorted list of atoms. It provides a simple way to know what types of seats
  are available in a ride without needing to manually parse the seats map.

  ## Why this is needed

  The `seats` attribute stores seat configuration as a map like `%{driver: 1, backseat: 3}`,
  but often we need just the list of seat types available. This calculation provides
  that information in a standardized format and handles the conversion from map keys
  (which may be strings or atoms) to a consistent atom list.

  ## Usage

  Load this calculation to get all seat types for a ride:

      ride = Ash.load!(ride, [:total_seat_types])
      ride.total_seat_types
      # => [:driver, :backseat, :window]

  ## Example

      iex> # Given a ride with seat configuration
      iex> ride = %{seats: %{driver: 1, backseat: 3, window: 2}}
      iex> # The calculation would return:
      iex> [:driver, :backseat, :window]
      
  This calculation is useful for:
  - UI components that need to show all available seat types
  - Validation logic that checks if a seat type is valid for a ride
  - Iterating over all possible seat types for analytics
  """
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    [:seats]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Get seats map: %{driver: 1, backseat: 2} (atom keys)
      # Return list of seat types as atoms: [:driver, :backseat]
      keys = (record.seats || %{}) |> Map.keys()
      
      # Convert string keys to atoms if they're strings, keep atoms as atoms
      keys
      |> Enum.map(fn 
        key when is_atom(key) -> key
        key when is_binary(key) -> String.to_atom(key)
      end)
      |> Enum.sort()
    end)
  end
end