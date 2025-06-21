defmodule Ridez.Validations.RequiredLicense do
  @moduledoc """
  Validates that a person has the required license to take the driver seat.

  This validation ensures that:
  1. If a ride has a required_license specified
  2. And the person is trying to take the :driver seat
  3. Then the person must have that license in their licences array

  For non-driver seats or rides without required_license, this validation passes.
  """
  use Ash.Resource.Validation

  alias Ridez.Rides.{Ride, Person}
  alias Ash.Changeset

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    seat = Changeset.get_attribute(changeset, :seat)
    ride_id = Changeset.get_attribute(changeset, :ride_id)
    person_id = Changeset.get_attribute(changeset, :person_id)

    # Only validate if trying to take the driver seat
    if seat == :driver && ride_id && person_id do
      validate_driver_license(ride_id, person_id)
    else
      :ok
    end
  end

  defp validate_driver_license(ride_id, person_id) do
    with {:ok, ride} <- Ash.get(Ride, ride_id),
         {:ok, person} <- Ash.get(Person, person_id) do
      check_license_requirement(ride.required_license, person.licences)
    else
      {:error, _} ->
        {:error, "Unable to load ride or person information"}
    end
  end

  defp check_license_requirement(nil, _licences) do
    # No license required, validation passes
    :ok
  end

  defp check_license_requirement(required_license, licences) when is_list(licences) do
    if required_license in licences do
      :ok
    else
      {:error, "Driver seat requires #{required_license} license"}
    end
  end

  defp check_license_requirement(required_license, _licences) do
    {:error, "Driver seat requires #{required_license} license"}
  end
end