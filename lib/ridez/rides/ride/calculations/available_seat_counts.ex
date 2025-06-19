defmodule Ridez.Rides.Ride.Calculations.AvailableSeatCounts do
  @moduledoc """
  Calculates the number of available seats by seat type for a ride.

  This calculation computes how many seats are still available for each seat type
  by subtracting taken seats from total seats. It returns a map where keys are
  seat types (as strings) and values are the count of available seats.

  ## Why this is needed

  This is a core calculation for seat availability logic. It provides the numerical
  foundation for determining which seat types have availability and is used by
  other calculations like `:available_seat_types` and `:has_available_seats?`.

  The calculation handles the math of `total_seats - taken_seats` for each seat type,
  ensuring the result is never negative (uses `max(0, difference)`).

  ## Usage

  Load this calculation to get available seat counts by type:

      ride = Ash.load!(ride, [:available_seat_counts])
      ride.available_seat_counts
      # => %{"driver" => 0, "backseat" => 2, "window" => 2}

  ## Example

      iex> # Given a ride with some seats taken
      iex> ride = %{
      iex>   seats: %{driver: 1, backseat: 3, window: 2},
      iex>   taken_seat_counts: %{"driver" => 1, "backseat" => 1}
      iex> }
      iex> # The calculation would return:
      iex> %{"driver" => 0, "backseat" => 2, "window" => 2}
      
  This calculation is essential for:
  - Booking systems that need to show exact availability per seat type
  - Analytics that track seat utilization
  - Capacity planning and ride optimization
  """
  use Ash.Resource.Calculation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, _context) do
    [:seats, :taken_seat_counts]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, fn record ->
      # Get total seats: %{driver: 1, backseat: 3} (atoms as keys)
      total_seats = record.seats || %{}

      # Get taken seats: %{"driver" => 1, "backseat" => 2} (strings as keys from aggregate)
      taken_seats = record.taken_seat_counts || %{}

      # Calculate available: total - taken for each seat type
      # Convert atom keys to string keys for consistency
      total_seats
      |> Enum.into(%{}, fn {seat_type, total_count} ->
        seat_string = to_string(seat_type)
        taken_count = Map.get(taken_seats, seat_string, 0)
        available_count = max(0, total_count - taken_count)
        {seat_string, available_count}
      end)
    end)
  end
end