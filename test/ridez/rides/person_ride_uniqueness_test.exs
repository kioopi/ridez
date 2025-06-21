defmodule Ridez.Rides.PersonRideUniquenessTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Rides

  require Ash.Query

  describe "Person-Ride uniqueness validation" do
    test "allows creating a person-ride relationship" do
      person = generate(person())
      ride = generate(ride(seats: [:driver, :passenger]))

      Rides.join_ride!(ride.id, person.id, :driver)

      # Verify relationship was created
      ride = Ash.load!(ride, [:people])
      assert length(ride.people) == 1
      assert hd(ride.people).id == person.id
    end

    test "prevents creating duplicate person-ride relationships with same seat" do
      person = generate(person())

      ride =
        generate(
          ride(
            seats: [passenger: 2],
            people: [driver: person.id]
          )
        )

      # Attempt to create duplicate relationship with same seat
      assert_raise Ash.Error.Invalid, fn ->
        Rides.join_ride!(ride.id, person.id, :driver)
      end
    end

    test "prevents creating duplicate person-ride relationships with different seats" do
      person = generate(person())

      ride =
        generate(
          ride(
            seats: [:driver, passenger: 2],
            people: [driver: person.id]
          )
        )

      # Attempt to create duplicate relationship with different seat
      assert_raise Ash.Error.Invalid, fn ->
        Rides.join_ride!(ride.id, person.id, :passenger)
      end
    end

    test "allows same person on different rides" do
      person = generate(person())
      ride1 = generate(ride(seats: [:driver]))
      ride2 = generate(ride(seats: [:driver]))

      # Create relationship with first ride
      Rides.join_ride!(ride1.id, person.id, :driver)

      # Create relationship with second ride (should succeed)
      Rides.join_ride!(ride2.id, person.id, :driver)

      # Verify both relationships exist
      ride1 = Ash.load!(ride1, [:people])
      ride2 = Ash.load!(ride2, [:people])

      assert length(ride1.people) == 1
      assert length(ride2.people) == 1
      assert hd(ride1.people).id == person.id
      assert hd(ride2.people).id == person.id
    end

    test "allows different people on same ride" do
      [person1, person2] = generate_many(person(), 2)
      ride = generate(ride(seats: [:driver, :passenger]))

      # Create relationships with both people
      Rides.join_ride!(ride.id, person1.id, :driver)
      Rides.join_ride!(ride.id, person2.id, :passenger)

      # Verify both relationships exist
      ride = Ash.load!(ride, [:people])
      person_ids = Enum.map(ride.people, & &1.id) |> Enum.sort()
      expected_ids = [person1.id, person2.id] |> Enum.sort()

      assert length(ride.people) == 2
      assert person_ids == expected_ids
    end

    test "provides clear error message for duplicate relationships" do
      person = generate(person())
      ride = generate(ride(seats: [:driver, :passenger]))

      # Create first relationship
      Rides.join_ride!(ride.id, person.id, :driver)

      # Attempt duplicate and check error message
      try do
        Rides.join_ride!(ride.id, person.id, :passenger)
      rescue
        error in Ash.Error.Invalid ->
          error_messages =
            error.errors
            |> Enum.map(& &1.message)
            |> Enum.join(", ")

          assert String.contains?(error_messages, "already") or
                   String.contains?(error_messages, "duplicate") or
                   String.contains?(error_messages, "unique")
      end
    end

    test "validation works through domain interface with non-bang functions" do
      person = generate(person())
      ride = generate(ride(seats: [:driver, :passenger]))

      # Create first relationship using domain interface
      assert {:ok, _person_ride} = Rides.join_ride(ride.id, person.id, :driver)

      # Attempt duplicate using domain interface
      assert {:error, error} = Rides.join_ride(ride.id, person.id, :passenger)
      assert %Ash.Error.Invalid{} = error
    end
  end
end
