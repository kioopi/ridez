defmodule Ridez.Rides.PersonRideTriggerDirectTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Repo

  describe "Database trigger direct testing" do
    test "trigger function exists and is properly installed" do
      # Check that the trigger function exists
      {:ok, result} = Repo.query("SELECT prosrc FROM pg_proc WHERE proname = 'validate_driver_license_trigger'")
      assert length(result.rows) == 1

      # Check that the trigger is installed on person_rides table
      {:ok, result} = Repo.query("""
        SELECT tgname FROM pg_trigger 
        WHERE tgrelid = 'person_rides'::regclass 
        AND tgname = 'validate_driver_license_trigger'
      """)
      assert length(result.rows) == 1
    end

    test "trigger prevents invalid license through manual SQL using binary UUIDs" do
      person = generate(person(%{licences: [:motorcycle]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # Convert UUIDs to binary format for PostgreSQL
      person_uuid = Ecto.UUID.dump!(person.id)
      ride_uuid = Ecto.UUID.dump!(ride.id)

      # This should fail due to database trigger
      assert_raise Postgrex.Error, fn ->
        Repo.query!(
          "INSERT INTO person_rides (person_id, ride_id, seat) VALUES ($1, $2, $3)",
          [person_uuid, ride_uuid, "driver"],
          prepare: :unnamed
        )
      end
    end

    test "trigger allows valid license through manual SQL using binary UUIDs" do
      person = generate(person(%{licences: [:car]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # Convert UUIDs to binary format for PostgreSQL  
      person_uuid = Ecto.UUID.dump!(person.id)
      ride_uuid = Ecto.UUID.dump!(ride.id)

      # This should succeed
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (person_id, ride_id, seat) VALUES ($1, $2, $3)",
        [person_uuid, ride_uuid, "driver"],
        prepare: :unnamed
      )

      # Verify it was inserted
      {:ok, result} = Repo.query(
        "SELECT COUNT(*) FROM person_rides WHERE person_id = $1 AND ride_id = $2",
        [person_uuid, ride_uuid]
      )
      assert [[1]] = result.rows
    end

    test "trigger allows passenger without license through manual SQL" do
      person = generate(person(%{licences: []}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1, passenger: 1}}))

      # Convert UUIDs to binary format for PostgreSQL
      person_uuid = Ecto.UUID.dump!(person.id)
      ride_uuid = Ecto.UUID.dump!(ride.id)

      # This should succeed (passengers don't need licenses)
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (person_id, ride_id, seat) VALUES ($1, $2, $3)",
        [person_uuid, ride_uuid, "passenger"],
        prepare: :unnamed
      )

      # Verify it was inserted
      {:ok, result} = Repo.query(
        "SELECT COUNT(*) FROM person_rides WHERE person_id = $1 AND ride_id = $2",
        [person_uuid, ride_uuid]
      )
      assert [[1]] = result.rows
    end

    test "trigger error message contains license information" do
      person = generate(person(%{licences: [:motorcycle]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # Convert UUIDs to binary format
      person_uuid = Ecto.UUID.dump!(person.id)
      ride_uuid = Ecto.UUID.dump!(ride.id)

      try do
        Repo.query!(
          "INSERT INTO person_rides (person_id, ride_id, seat) VALUES ($1, $2, $3)",
          [person_uuid, ride_uuid, "driver"],
          prepare: :unnamed
        )
        flunk("Expected Postgrex.Error but query succeeded")
      rescue
        error in Postgrex.Error ->
          # Verify error contains license requirement information
          error_text = error.postgres.message
          assert String.contains?(error_text, "Driver seat requires")
          assert String.contains?(error_text, "car")
      end
    end

    test "trigger bypassed shows it works as safety net beyond Ash validations" do
      # This test demonstrates that even if we bypass Ash's validation system,
      # the database trigger still enforces the constraint
      person = generate(person(%{licences: [:motorcycle]}))
      ride = generate(ride(%{required_license: :car, seats: %{driver: 1}}))

      # Use Ash.create with bypass to skip some validations, but trigger should still catch it
      person_ride_attrs = %{
        person_id: person.id,
        ride_id: ride.id,
        seat: :driver
      }

      # This should still fail due to the database trigger acting as a safety net
      assert {:error, %Ash.Error.Invalid{}} = 
        Ash.create(Ridez.Rides.PersonRide, person_ride_attrs, authorize?: false)
    end
  end
end