defmodule Ridez.Rides.PersonRideDatabaseConstraintTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Repo

  describe "Database-level uniqueness constraint enforcement" do
    test "database prevents duplicate person-ride relationships via unique constraint" do
      person = generate(person())
      ride = generate(ride(seats: %{driver: 1, passenger: 1}))

      # Insert first record directly via SQL
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
        [
          Ecto.UUID.dump!(Ash.UUID.generate()),
          Ecto.UUID.dump!(person.id),
          Ecto.UUID.dump!(ride.id),
          "driver"
        ]
      )

      # Attempt to insert duplicate record directly via SQL
      assert_raise Postgrex.Error, fn ->
        Repo.query!(
          "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
          [
            Ecto.UUID.dump!(Ash.UUID.generate()),
            Ecto.UUID.dump!(person.id),
            Ecto.UUID.dump!(ride.id),
            "passenger"  # Different seat, but same person-ride combination
          ]
        )
      end
    end

    test "database constraint prevents concurrent insertions" do
      person = generate(person())
      ride = generate(ride(seats: %{driver: 1, passenger: 2}))

      # Simulate concurrent insertions using separate transactions
      task1 = Task.async(fn ->
        Repo.transaction(fn ->
          # Add small delay to increase chance of race condition
          Process.sleep(10)
          
          Repo.query(
            "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
            [
              Ecto.UUID.dump!(Ash.UUID.generate()),
              Ecto.UUID.dump!(person.id),
              Ecto.UUID.dump!(ride.id),
              "driver"
            ]
          )
        end)
      end)

      task2 = Task.async(fn ->
        Repo.transaction(fn ->
          # Add small delay to increase chance of race condition
          Process.sleep(10)
          
          Repo.query(
            "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
            [
              Ecto.UUID.dump!(Ash.UUID.generate()),
              Ecto.UUID.dump!(person.id),
              Ecto.UUID.dump!(ride.id),
              "passenger"  # Different seat, same person-ride
            ]
          )
        end)
      end)

      # One should succeed, one should fail
      results = [Task.await(task1), Task.await(task2)]
      
      success_count = Enum.count(results, fn
        {:ok, _} -> true
        _ -> false
      end)
      
      error_count = Enum.count(results, fn
        {:error, _} -> true
        _ -> false
      end)

      # Exactly one should succeed, one should fail due to constraint
      assert success_count == 1
      assert error_count == 1
    end

    test "database allows same person on different rides" do
      person = generate(person())
      ride1 = generate(ride(seats: %{driver: 1}))
      ride2 = generate(ride(seats: %{driver: 1}))

      # Insert first record
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
        [
          Ecto.UUID.dump!(Ash.UUID.generate()),
          Ecto.UUID.dump!(person.id),
          Ecto.UUID.dump!(ride1.id),
          "driver"
        ]
      )

      # Insert second record with same person, different ride (should succeed)
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
        [
          Ecto.UUID.dump!(Ash.UUID.generate()),
          Ecto.UUID.dump!(person.id),
          Ecto.UUID.dump!(ride2.id),
          "driver"
        ]
      )

      # Verify both records exist
      {:ok, result} = Repo.query(
        "SELECT COUNT(*) FROM person_rides WHERE person_id = $1",
        [Ecto.UUID.dump!(person.id)]
      )

      assert [[2]] = result.rows
    end

    test "database allows different people on same ride" do
      person1 = generate(person())
      person2 = generate(person())
      ride = generate(ride(seats: %{driver: 1, passenger: 1}))

      # Insert first record
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
        [
          Ecto.UUID.dump!(Ash.UUID.generate()),
          Ecto.UUID.dump!(person1.id),
          Ecto.UUID.dump!(ride.id),
          "driver"
        ]
      )

      # Insert second record with different person, same ride (should succeed)
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
        [
          Ecto.UUID.dump!(Ash.UUID.generate()),
          Ecto.UUID.dump!(person2.id),
          Ecto.UUID.dump!(ride.id),
          "passenger"
        ]
      )

      # Verify both records exist
      {:ok, result} = Repo.query(
        "SELECT COUNT(*) FROM person_rides WHERE ride_id = $1",
        [Ecto.UUID.dump!(ride.id)]
      )

      assert [[2]] = result.rows
    end

    test "database constraint error contains useful information" do
      person = generate(person())
      ride = generate(ride(seats: %{driver: 1, passenger: 1}))

      # Insert first record
      {:ok, _result} = Repo.query(
        "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
        [
          Ecto.UUID.dump!(Ash.UUID.generate()),
          Ecto.UUID.dump!(person.id),
          Ecto.UUID.dump!(ride.id),
          "driver"
        ]
      )

      # Attempt duplicate insertion and capture error details
      try do
        Repo.query!(
          "INSERT INTO person_rides (id, person_id, ride_id, seat) VALUES ($1, $2, $3, $4)",
          [
            Ecto.UUID.dump!(Ash.UUID.generate()),
            Ecto.UUID.dump!(person.id),
            Ecto.UUID.dump!(ride.id),
            "passenger"
          ]
        )
        # If we reach here, the test should fail
        flunk("Expected constraint violation error")
      rescue
        error in Postgrex.Error ->
          # Verify error contains constraint information
          assert error.postgres.code == :unique_violation
          assert is_binary(error.postgres.message)
          assert String.contains?(error.postgres.message, "unique") or 
                 String.contains?(error.postgres.message, "duplicate")
      end
    end

    test "verifies unique constraint exists in database schema" do
      # Query database to verify the unique index exists (which enforces uniqueness)
      {:ok, result} = Repo.query("""
        SELECT indexname, indexdef
        FROM pg_indexes 
        WHERE tablename = 'person_rides' 
        AND indexdef ILIKE '%unique%'
        AND indexdef ILIKE '%person_id%'
        AND indexdef ILIKE '%ride_id%'
      """)

      # Should have at least one unique index on person_id and ride_id
      assert length(result.rows) >= 1
      
      # Get the first unique index and verify it covers both columns
      [first_index | _] = result.rows
      [_index_name, index_definition] = first_index
      
      # Verify the index covers both person_id and ride_id
      assert String.contains?(index_definition, "person_id")
      assert String.contains?(index_definition, "ride_id")
      assert String.contains?(String.downcase(index_definition), "unique")
    end
  end
end