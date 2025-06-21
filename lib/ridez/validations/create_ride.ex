defmodule Ridez.Validations.CreateRide do
  @moduledoc """
  Validates seat availability when creating a ride.

  When creating a ride, the validations on PeopleRides cannot access the Ride
  because it has not been created yet. This validation ensures that the seat
  availability requirements are met by validating against the seats attribute
  that will be used to add the available seats on the ride being created.
  """

  use Ash.Resource.Validation

  import Ash.Changeset, only: [get_argument: 2, get_attribute: 2]
  import Ridez.Changes.PeopleSeats, only: [required_seats: 1]

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    seats = get_attribute(changeset, :seats)

    case get_argument(changeset, :people) do
      nil -> :ok
      people -> validate_seat_requirements(required_seats(people), seats)
    end
  end

  defp validate_seat_requirements(required_seats, available_seats) do
    check_seats_available = fn {seat, ammount} ->
      Map.get(available_seats, seat, 0) >= ammount
    end

    if Enum.all?(required_seats, check_seats_available) do
      :ok
    else
      {:error, "Not all required seats are available. Add them to the seats argument"}
    end
  end
end
