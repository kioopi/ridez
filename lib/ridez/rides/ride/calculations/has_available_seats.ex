defmodule Ridez.Rides.Ride.Calculations.HasAvailableSeats do
  @moduledoc """
  Calculates whether a ride has any available seats for booking.

  This calculation returns a boolean indicating if there are any seat types
  with available capacity. It's a quick way to check ride availability without
  needing to examine detailed seat counts or types.

  ## Why this is needed

  This calculation provides a fast, simple answer to "can passengers join this ride?"
  It's perfect for:
  - Filtering rides in search results to show only bookable rides
  - Quick validation before allowing booking attempts
  - Dashboard metrics showing ride availability statistics
  - API responses that need a simple yes/no availability status

  The calculation is more efficient than checking `length(available_seat_types) > 0`
  in client code, as it's computed once and cached by Ash.

  ## Usage

  Load this calculation for quick availability checks:

      ride = Ash.load!(ride, [:has_available_seats?])
      
      if ride.has_available_seats? do
        # Show booking interface
      else
        # Show "fully booked" message
      end

  Use in queries to filter available rides:

      available_rides = MyDomain.list_rides!(
        filter: [has_available_seats?: true]
      )

  ## Example

      iex> # Given a ride with some availability
      iex> ride = %{available_seat_types: [:backseat, :window]}
      iex> # The calculation would return:
      iex> true

      iex> # Given a fully booked ride
      iex> ride = %{available_seat_types: []}
      iex> # The calculation would return:
      iex> false
      
  This boolean result makes it easy to use in conditional logic and filters.
  """
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    [:available_seat_types]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Return true if there are any available seat types
      available_types = record.available_seat_types || []
      length(available_types) > 0
    end)
  end
end