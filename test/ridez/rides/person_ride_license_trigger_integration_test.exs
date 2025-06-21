defmodule Ridez.Rides.PersonRideLicenseTriggerIntegrationTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Rides

  describe "Database trigger integration with Ash domain" do
    test "trigger prevents driver without required license via Ash join_ride" do
      person = generate(person(%{licences: [:motorcycle]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # This should fail due to both Ash validation AND database trigger
      assert {:error, %Ash.Error.Invalid{}} = 
        Rides.join_ride(ride.id, person.id, :driver)
    end

    test "trigger allows driver with required license via Ash join_ride" do
      person = generate(person(%{licences: [:car]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # This should succeed
      assert {:ok, _person_ride} = 
        Rides.join_ride(ride.id, person.id, :driver)
    end

    test "trigger allows driver when no license required via Ash join_ride" do
      person = generate(person(%{licences: []}))
      ride = generate(ride(%{required_license: nil, seats: %{driver: 1}}))

      # This should succeed even with no licenses
      assert {:ok, _person_ride} = 
        Rides.join_ride(ride.id, person.id, :driver)
    end

    test "trigger allows passenger without license via Ash join_ride" do
      person = generate(person(%{licences: []}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1, passenger: 1}}))

      # This should succeed - trigger only checks drivers
      assert {:ok, _person_ride} = 
        Rides.join_ride(ride.id, person.id, :passenger)
    end

    test "trigger allows driver with multiple licenses including required one" do
      person = generate(person(%{licences: [:motorcycle, :car, :truck]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # This should succeed
      assert {:ok, _person_ride} = 
        Rides.join_ride(ride.id, person.id, :driver)
    end

    test "trigger prevents driver with empty license array" do
      person = generate(person(%{licences: []}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # This should fail due to both Ash validation AND database trigger
      assert {:error, %Ash.Error.Invalid{}} = 
        Rides.join_ride(ride.id, person.id, :driver)
    end

    test "database trigger works as final validation layer" do
      # Test that even if we somehow bypass Ash validation,
      # the database trigger still prevents invalid data
      person = generate(person(%{licences: [:motorcycle]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # Use Ash.create directly to potentially bypass some validations
      assert {:error, _} = Ash.create(Ridez.Rides.PersonRide, %{
        person_id: person.id,
        ride_id: ride.id,
        seat: :driver
      })
    end
  end
end