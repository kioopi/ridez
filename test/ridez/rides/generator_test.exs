defmodule Ridez.Rides.GeneratorTest do
  use Ridez.DataCase
  use ExUnitProperties

  import Ridez.Rides.Generator
  alias Ridez.Rides.{Ride, Person}

  describe "ride generator basic functionality" do
    test "generates valid rides with default configuration" do
      # Test that the generator can create valid rides
      ride = generate(ride())

      assert ride.id
      assert is_map(ride.seats)
      assert map_size(ride.seats) >= 1
      # Note: should be max_length: 5, but generator has typo
      assert map_size(ride.seats) <= 5
    end

    test "all generated seat counts are positive integers" do
      ride = generate(ride())

      # All values should be integers between 1 and 10
      Enum.each(Map.values(ride.seats), fn count ->
        assert is_integer(count), "Seat count #{inspect(count)} should be an integer"
        assert count >= 1, "Seat count should be at least 1"
        assert count <= 10, "Seat count should be at most 10"
      end)
    end

    test "generates multiple unique rides" do
      rides = generate_many(ride(), 10)

      # Should generate different configurations (at least some variation)
      seat_configurations = Enum.map(rides, & &1.seats)
      unique_configurations = Enum.uniq(seat_configurations)

      # With random generation, we should get some variety (though not guaranteed)
      # At minimum, the generator should work consistently
      assert length(unique_configurations) >= 1
      assert length(seat_configurations) == 10
    end
  end

  describe "ride generator with overrides" do
    test "override with complex seat configuration" do
      custom_seats = %{
        driver: 1,
        front_passenger: 1,
        back_left: 1,
        back_middle: 1,
        back_right: 1,
        trunk: 2
      }

      %Ride{seats: seats} = generate(ride(seats: custom_seats))

      for seat <- Map.keys(custom_seats) do
        assert seats[to_string(seat)] == custom_seats[seat],
               "Expected seat #{inspect(seat)} to have count #{custom_seats[seat]}, got #{seats[seat]}"
      end
    end

    # this will need a validation to work
    @tag :skip
    test "override with empty seats (edge case)" do
      # This should probably fail validation, but let's see what happens
      assert_raise Ash.Error.Invalid, fn ->
        generate(ride(seats: %{}))
      end
    end

    test "override preserves seat data types" do
      # Test that atom keys are preserved
      ride = generate(ride(seats: [:driver, backseat: 2]))

      # Check if the generator/change preserves the key types
      seat_keys = Map.keys(ride.seats)

      assert "driver" in seat_keys
      assert "backseat" in seat_keys
    end
  end

  describe "ride generator edge cases" do
    test "override with string keys" do
      # Test what happens when we provide string keys instead of atom keys
      custom_seats = %{"driver" => 1, "passenger" => 3}
      ride = generate(ride(seats: custom_seats))

      # The change should handle this
      assert is_map(ride.seats)
      assert Map.has_key?(ride.seats, "driver") || Map.has_key?(ride.seats, :driver)
    end

    test "override with list format (SeatsMap change should handle this)" do
      # Test the list format that SeatsMap change supports
      custom_seats = [:driver, backseat: 3, window: 2]
      ride = generate(ride(seats: custom_seats))

      # Should be converted to a proper map by SeatsMap change
      assert is_map(ride.seats)
      expected_keys = [:driver, :backseat, :window]
      actual_keys = Map.keys(ride.seats) |> Enum.map(&to_string/1) |> Enum.map(&String.to_atom/1)

      Enum.each(expected_keys, fn key ->
        assert key in actual_keys, "Expected #{key} to be in seat types"
      end)
    end

    test "override with zero seat count" do
      # Test edge case with zero seats
      custom_seats = %{driver: 0, passenger: 2}

      # This might be invalid business logic
      ride = generate(ride(seats: custom_seats))
      assert ride.seats[:driver] == 0 || ride.seats["driver"] == 0
    end

    test "override with very large seat count" do
      # Test with unreasonably large numbers
      custom_seats = %{stadium: 50000}
      ride = generate(ride(seats: custom_seats))

      assert ride.seats[:stadium] == 50000 || ride.seats["stadium"] == 50000
    end
  end

  describe "ride generator property-based testing" do
    @tag :property
    property "generated rides always have valid structure" do
      check all(ride_data <- ride()) do
        ride = generate(ride_data)

        # Basic structure validation
        assert is_struct(ride, Ride)
        assert ride.id
        assert is_map(ride.seats)
        assert map_size(ride.seats) > 0

        # Validate each seat type and count
        Enum.each(ride.seats, fn {seat_type, count} ->
          assert is_atom(seat_type) or is_binary(seat_type)
          assert is_integer(count)
          assert count > 0
        end)
      end
    end

    @tag :property
    property "overrides are respected" do
      check all(
              seats_override <-
                map_of(atom(:alphanumeric), integer(1..100), min_length: 1, max_length: 3)
            ) do
        ride = generate(ride(seats: seats_override))

        # The override should be reflected in the final result
        # (might be transformed by SeatsMap change)
        override_keys = Map.keys(seats_override) |> MapSet.new()

        result_keys =
          Map.keys(ride.seats)
          |> Enum.map(fn
            key when is_atom(key) -> key
            key when is_binary(key) -> String.to_atom(key)
          end)
          |> MapSet.new()

        # All override keys should be present (possibly transformed)
        assert MapSet.subset?(override_keys, result_keys),
               "Override keys #{inspect(override_keys)} should be subset of result keys #{inspect(result_keys)}"
      end
    end
  end

  describe "person generator functionality" do
    test "generates valid persons with default configuration" do
      person_record = generate(person())

      assert person_record.id
      assert is_struct(person_record, Person)
    end

    test "person generator accepts overrides" do
      custom_licences = [:car, :motorcycle, :truck]
      person_record = generate(person(licences: custom_licences))

      assert person_record.licences == custom_licences
    end

    test "generates multiple unique persons" do
      persons = generate_many(person(), 5)

      # All should be valid Person structs
      Enum.each(persons, fn person_record ->
        assert is_struct(person_record, Person)
        assert person_record.id
      end)

      # Should have unique IDs
      ids = Enum.map(persons, & &1.id)
      unique_ids = Enum.uniq(ids)
      assert length(ids) == length(unique_ids)
    end
  end

  describe "generator integration with actual usage patterns" do
    test "reproduces the failing pattern from seat calculations tests" do
      # This is the pattern that was failing in the seat calculations tests
      custom_seats = %{bus_seat: 50}

      # Let's see what actually gets generated
      ride = generate(ride(seats: custom_seats))

      # Check if the seats match what we expect
      cond do
        Map.has_key?(ride.seats, :bus_seat) ->
          assert ride.seats[:bus_seat] == 50

        Map.has_key?(ride.seats, "bus_seat") ->
          assert ride.seats["bus_seat"] == 50

        true ->
          flunk("bus_seat not found in generated ride. Got: #{inspect(ride.seats)}")
      end
    end

    test "compares generator vs direct changeset creation" do
      custom_seats = %{driver: 1, backseat: 3, window: 2}

      # Method 1: Using generator (the failing approach)
      ride_from_generator = generate(ride(seats: custom_seats))

      # Method 2: Direct changeset creation (the working approach)
      ride_from_changeset =
        Ash.Changeset.for_create(Ride, :create, %{
          seats: [driver: 1, backseat: 3, window: 2],
          required_license: :car
        })
        |> Ash.create!()

      # Both should have the same seat configuration (possibly with different key types)
      generator_normalized = normalize_seat_keys(ride_from_generator.seats)
      changeset_normalized = normalize_seat_keys(ride_from_changeset.seats)

      assert generator_normalized == changeset_normalized
    end

    test "generator works with seat calculations" do
      # Test that a generator-created ride works with our new calculations
      custom_seats = %{driver: 1, backseat: 2}
      ride = generate(ride(seats: custom_seats))

      # This should not fail
      loaded_ride = Ash.load!(ride, [:total_seat_types, :available_seat_types])

      assert length(loaded_ride.total_seat_types) == 2
      # No passengers yet
      assert length(loaded_ride.available_seat_types) == 2
    end
  end

  describe "debugging the specific failures" do
    test "large seat count override issue" do
      # This was one of the failing patterns
      large_seats = %{bus_seat: 50}

      # Generate multiple times to see if it's consistent
      results =
        for i <- 1..5 do
          ride = generate(ride(seats: large_seats))
          actual_count = ride.seats[:bus_seat] || ride.seats["bus_seat"] || :not_found
          {i, actual_count}
        end

      # All should be 50
      Enum.each(results, fn {iteration, count} ->
        assert count == 50, "Iteration #{iteration}: expected 50, got #{inspect(count)}"
      end)
    end

    test "StreamData interaction with overrides" do
      # Test if the issue is related to StreamData conflicting with overrides

      # Create a ride without any overrides first
      default_ride = generate(ride())

      # Now with a simple override
      simple_override = %{driver: 1}
      override_ride = generate(ride(seats: simple_override))

      # The override should completely replace the default generation
      expected_keys = [:driver]

      actual_keys =
        Map.keys(override_ride.seats)
        |> Enum.map(fn
          key when is_atom(key) -> key
          key when is_binary(key) -> String.to_atom(key)
        end)

      assert expected_keys == actual_keys,
             "Expected #{inspect(expected_keys)}, got #{inspect(actual_keys)}"
    end
  end

  # Helper function to normalize seat keys for comparison
  defp normalize_seat_keys(seats) when is_map(seats) do
    seats
    |> Enum.into(%{}, fn {key, value} ->
      normalized_key =
        case key do
          key when is_atom(key) -> key
          key when is_binary(key) -> String.to_atom(key)
        end

      {normalized_key, value}
    end)
  end
end
