defmodule Ridez.Validations.SeatAvailable do
  @moduledoc """
  Validates that a seat is available when someone tries to join a ride.

  This validation ensures that:
  1. The requested seat type exists on the ride
  2. There are available seats of the requested type (not fully booked)

  The validation loads the ride's available_seat_counts calculation to determine
  if the requested seat type has any availability.
  """
  use Ash.Resource.Validation

  alias Ridez.Rides.Ride
  alias Ash.Changeset

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    seat = Changeset.get_attribute(changeset, :seat)
    ride_id = Changeset.get_attribute(changeset, :ride_id)

    if seat && ride_id do
      case Ash.get(Ride, ride_id, load: [:available_seat_counts]) do
        {:ok, ride} ->
          validate_seat_availability(seat, ride)

        {:error, _} ->
          {:error, "Unable to load ride information"}
      end
    else
      :ok
    end
  end

  defp validate_seat_availability(seat, ride) do
    seat_string = to_string(seat)
    available_counts = ride.available_seat_counts || %{}

    case Map.get(available_counts, seat_string) do
      nil ->
        {:error, "Seat type '#{seat}' does not exist on this ride"}

      0 ->
        {:error, "No seats of type '#{seat}' are available on this ride"}

      count when count > 0 ->
        :ok
    end
  end
end
