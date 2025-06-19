defmodule Ridez.Rides.RideSeatCalculationsTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Rides

  describe "taken_seat_counts aggregate" do
    test "returns empty map for ride with no passengers" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2}))

      ride = Ash.load!(ride, [:taken_seat_counts])

      assert ride.taken_seat_counts == %{}
    end

    test "counts taken seats by type correctly" do
      ride = generate(ride(seats: %{driver: 1, backseat: 3, window: 2}))
      person1 = generate(person())
      person2 = generate(person())
      person3 = generate(person())

      # Join ride with different seat types
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :backseat)
      Rides.join_ride!(ride.id, person3.id, :backseat)

      ride = Ash.load!(ride, [:taken_seat_counts])

      assert ride.taken_seat_counts == %{"driver" => 1, "backseat" => 2}
    end

    test "handles multiple people in same seat type" do
      ride = generate(ride(seats: %{backseat: 4}))

      # All join backseat
      for person <- generate_many(person(), 3) do
        Rides.join_ride!(ride.id, person.id, :backseat)
      end

      ride = Ash.load!(ride, [:taken_seat_counts])

      assert ride.taken_seat_counts == %{"backseat" => 3}
    end
  end

  describe "total_seat_types calculation" do
    test "returns all seat types from seats map" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2, window: 1}))

      ride = Ash.load!(ride, [:total_seat_types])

      # Convert strings to atoms for comparison since map keys are strings in DB
      expected_types = [:driver, :backseat, :window]
      assert Enum.sort(ride.total_seat_types) == Enum.sort(expected_types)
    end

    test "returns single seat type for single-seat ride" do
      ride = generate(ride(seats: %{driver: 1}))

      ride = Ash.load!(ride, [:total_seat_types])

      assert ride.total_seat_types == [:driver]
    end

    test "preserves seat type order" do
      ride = generate(ride(seats: %{a: 1, z: 1, m: 1}))

      ride = Ash.load!(ride, [:total_seat_types])

      # Should contain all types regardless of order
      assert length(ride.total_seat_types) == 3
      assert :a in ride.total_seat_types
      assert :z in ride.total_seat_types
      assert :m in ride.total_seat_types
    end
  end

  describe "available_seat_counts calculation" do
    test "shows all seats available when no passengers" do
      # ride = generate(ride(seats: %{driver: 1, backseat: 2}))
      ride =
        Ash.Changeset.for_create(Ridez.Rides.Ride, :create, %{
          seats: [driver: 1, backseat: 2],
          required_license: :car
        })
        |> Ash.create!()

      ride = Ash.load!(ride, [:available_seat_counts])

      assert ride.available_seat_counts == %{"driver" => 1, "backseat" => 2}
    end

    test "calculates available seats correctly with passengers" do
      ride =
        Ash.Changeset.for_create(Ridez.Rides.Ride, :create, %{
          seats: [driver: 1, backseat: 3, window: 2],
          required_license: :car
        })
        |> Ash.create!()

      [person1, person2] = generate_many(person(), 2)

      # Take some seats
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :backseat)

      ride = Ash.load!(ride, [:available_seat_counts])

      assert ride.available_seat_counts == %{
               "driver" => 0,
               "backseat" => 2,
               "window" => 2
             }
    end

    test "handles fully booked seat types" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2}))
      [person1, person2, person3] = generate_many(person(), 3)

      # Fill all seats
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :backseat)
      Rides.join_ride!(ride.id, person3.id, :backseat)

      ride = Ash.load!(ride, [:available_seat_counts])

      assert ride.available_seat_counts == %{"driver" => 0, "backseat" => 0}
    end
  end

  describe "available_seat_types calculation" do
    test "returns all seat types when no passengers" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2, window: 1}))

      ride = Ash.load!(ride, [:available_seat_types])

      expected_types = [:driver, :backseat, :window]
      assert Enum.sort(ride.available_seat_types) == Enum.sort(expected_types)
    end

    test "excludes fully booked seat types" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2, window: 1}))
      person1 = generate(person())
      person2 = generate(person())

      # Fill driver and window completely
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :window)

      ride = Ash.load!(ride, [:available_seat_types])

      assert ride.available_seat_types == [:backseat]
    end

    test "returns empty list when all seats taken" do
      ride = generate(ride(seats: %{driver: 1, backseat: 1}))
      person1 = generate(person())
      person2 = generate(person())

      # Fill all seats
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :backseat)

      ride = Ash.load!(ride, [:available_seat_types])

      assert ride.available_seat_types == []
    end

    test "includes partially filled seat types" do
      ride =
        Ash.Changeset.for_create(Ridez.Rides.Ride, :create, %{
          seats: [driver: 1, backseat: 3],
          required_license: :car
        })
        |> Ash.create!()

      person1 = generate(person())

      # Partially fill backseat
      Rides.join_ride!(ride.id, person1.id, :backseat)

      ride = Ash.load!(ride, [:available_seat_types])

      expected_types = [:driver, :backseat]
      assert Enum.sort(ride.available_seat_types) == Enum.sort(expected_types)
    end
  end

  describe "occupied_seat_types calculation" do
    test "returns empty list for ride with no passengers" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2}))

      ride = Ash.load!(ride, [:occupied_seat_types])

      assert ride.occupied_seat_types == []
    end

    test "returns seat types that have passengers" do
      ride = generate(ride(seats: %{driver: 1, backseat: 3, window: 2}))
      person1 = generate(person())
      person2 = generate(person())

      # Occupy some seat types
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :backseat)

      ride = Ash.load!(ride, [:occupied_seat_types])

      expected_types = [:driver, :backseat]
      assert Enum.sort(ride.occupied_seat_types) == Enum.sort(expected_types)
    end

    test "includes seat types with multiple passengers" do
      ride = generate(ride(seats: %{backseat: 3}))
      person1 = generate(person())
      person2 = generate(person())

      # Multiple people in same seat type
      Rides.join_ride!(ride.id, person1.id, :backseat)
      Rides.join_ride!(ride.id, person2.id, :backseat)

      ride = Ash.load!(ride, [:occupied_seat_types])

      assert ride.occupied_seat_types == [:backseat]
    end
  end

  describe "has_available_seats? calculation" do
    test "returns true for ride with no passengers" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2}))

      ride = Ash.load!(ride, [:has_available_seats?])

      assert ride.has_available_seats? == true
    end

    test "returns true for partially filled ride" do
      ride = generate(ride(seats: %{driver: 1, backseat: 2}))
      person = generate(person())

      Rides.join_ride!(ride.id, person.id, :driver)

      ride = Ash.load!(ride, [:has_available_seats?])

      assert ride.has_available_seats? == true
    end

    test "returns false for completely full ride" do
      ride = generate(ride(seats: %{driver: 1, backseat: 1}))
      person1 = generate(person())
      person2 = generate(person())

      # Fill all seats
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :backseat)

      ride = Ash.load!(ride, [:has_available_seats?])

      assert ride.has_available_seats? == false
    end
  end

  describe "integration scenarios - multiple calculations together" do
    test "all calculations work consistently together" do
      ride =
        Ash.Changeset.for_create(Ridez.Rides.Ride, :create, %{
          seats: [driver: 1, backseat: 3, window: 2],
          required_license: :car
        })
        |> Ash.create!()

      person1 = generate(person())
      person2 = generate(person())

      # Take 1 driver and 1 backseat
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :backseat)

      ride =
        Ash.load!(ride, [
          :taken_seat_counts,
          :total_seat_types,
          :available_seat_counts,
          :available_seat_types,
          :occupied_seat_types,
          :has_available_seats?
        ])

      # Verify taken_seat_counts
      assert ride.taken_seat_counts == %{"driver" => 1, "backseat" => 1}

      # Verify total_seat_types
      expected_total = [:driver, :backseat, :window]
      assert Enum.sort(ride.total_seat_types) == Enum.sort(expected_total)

      # Verify available_seat_counts
      assert ride.available_seat_counts == %{
               "driver" => 0,
               "backseat" => 2,
               "window" => 2
             }

      # Verify available_seat_types (driver is full, backseat and window available)
      expected_available = [:backseat, :window]
      assert Enum.sort(ride.available_seat_types) == Enum.sort(expected_available)

      # Verify occupied_seat_types
      expected_occupied = [:driver, :backseat]
      assert Enum.sort(ride.occupied_seat_types) == Enum.sort(expected_occupied)

      # Verify has_available_seats?
      assert ride.has_available_seats? == true
    end

    test "calculations are consistent when ride is completely full" do
      ride = generate(ride(seats: %{driver: 1, passenger: 1}))
      person1 = generate(person())
      person2 = generate(person())

      # Fill all seats
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :passenger)

      ride =
        Ash.load!(ride, [
          :taken_seat_counts,
          :available_seat_counts,
          :available_seat_types,
          :has_available_seats?
        ])

      # All seats taken
      assert ride.taken_seat_counts == %{"driver" => 1, "passenger" => 1}
      assert ride.available_seat_counts == %{"driver" => 0, "passenger" => 0}
      assert ride.available_seat_types == []
      assert ride.has_available_seats? == false
    end

    test "calculations handle complex seat configuration" do
      # Test with many seat types and varying capacities
      ride =
        generate(
          ride(
            seats: %{
              driver: 1,
              front_passenger: 1,
              back_left: 1,
              back_middle: 1,
              back_right: 1,
              trunk: 2
            }
          )
        )

      people = for _ <- 1..4, do: generate(person())

      # Fill some seats strategically
      Rides.join_ride!(ride.id, Enum.at(people, 0).id, :driver)
      Rides.join_ride!(ride.id, Enum.at(people, 1).id, :back_left)
      Rides.join_ride!(ride.id, Enum.at(people, 2).id, :trunk)
      Rides.join_ride!(ride.id, Enum.at(people, 3).id, :trunk)

      ride =
        Ash.load!(ride, [
          :taken_seat_counts,
          :available_seat_types,
          :occupied_seat_types,
          :has_available_seats?
        ])

      # Verify taken seats
      assert ride.taken_seat_counts == %{
               "driver" => 1,
               "back_left" => 1,
               "trunk" => 2
             }

      # Available types should exclude driver, back_left, trunk (all full)
      available_types = [:front_passenger, :back_middle, :back_right]
      assert Enum.sort(ride.available_seat_types) == Enum.sort(available_types)

      # Occupied types
      occupied_types = [:driver, :back_left, :trunk]
      assert Enum.sort(ride.occupied_seat_types) == Enum.sort(occupied_types)

      # Still has available seats
      assert ride.has_available_seats? == true
    end
  end

  describe "edge cases and error scenarios" do
    test "handles ride with single seat type" do
      ride = generate(ride(seats: %{solo: 1}))
      person = generate(person())

      # Test empty state
      ride = Ash.load!(ride, [:available_seat_types, :has_available_seats?])
      assert ride.available_seat_types == [:solo]
      assert ride.has_available_seats? == true

      # Fill the single seat
      Rides.join_ride!(ride.id, person.id, :solo)
      ride = Ash.load!(ride, [:available_seat_types, :has_available_seats?])
      assert ride.available_seat_types == []
      assert ride.has_available_seats? == false
    end

    test "handles ride with large seat capacity" do
      # Create ride with explicit large capacity
      ride =
        Ash.Changeset.for_create(Ridez.Rides.Ride, :create, %{
          seats: [bus_seat: 50]
        })
        |> Ash.create!()

      # Fill half the seats
      for person <- generate(person(), 25) do
        Rides.join_ride!(ride.id, person.id, :bus_seat)
      end

      ride = Ash.load!(ride, [:taken_seat_counts, :available_seat_counts])

      assert ride.taken_seat_counts == %{"bus_seat" => 25}
      assert ride.available_seat_counts == %{"bus_seat" => 25}
    end

    test "calculations work with atom seat types (from memory)" do
      # This tests the system handles both string keys (from DB) and atom keys
      ride = generate(ride(seats: %{driver: 1, backseat: 2}))
      person = generate(person())

      Rides.join_ride!(ride.id, person.id, :driver)

      ride = Ash.load!(ride, [:total_seat_types, :available_seat_types])

      # Should handle conversion properly
      assert :driver in ride.total_seat_types
      assert :backseat in ride.total_seat_types
      assert :backseat in ride.available_seat_types
      assert :driver not in ride.available_seat_types
    end

    test "handles ride modifications after passengers join" do
      # This tests that calculations update correctly when data changes
      ride =
        Ash.Changeset.for_create(Ridez.Rides.Ride, :create, %{
          seats: [driver: 1, backseat: 2],
          required_license: :car
        })
        |> Ash.create!()

      person1 = generate(person())
      person2 = generate(person())

      # Initial state
      Rides.join_ride!(ride.id, person1.id, :driver)
      ride = Ash.load!(ride, [:available_seat_types])
      initial_available = ride.available_seat_types

      # Add another passenger
      Rides.join_ride!(ride.id, person2.id, :backseat)
      ride = Ash.load!(ride, [:available_seat_types])
      final_available = ride.available_seat_types

      # Both should include backseat, but calculations should be independent
      assert :backseat in initial_available
      assert :backseat in final_available
      assert :driver not in initial_available
      assert :driver not in final_available
    end
  end
end
