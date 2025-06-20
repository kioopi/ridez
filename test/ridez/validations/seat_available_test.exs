defmodule Ridez.Validations.SeatAvailableTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Rides

  describe "SeatAvailable validation" do
    test "allows joining a ride when seat is available" do
      ride = generate(ride(seats: [:driver, backseat: 2]))
      person = generate(person())

      assert {:ok, _person_ride} = Rides.join_ride(ride.id, person.id, :driver)
    end

    test "allows multiple people to join the same seat type when multiple seats available" do
      ride = generate(ride(seats: [backseat: 2]))
      [person1, person2] = generate_many(person(), 2)

      assert {:ok, _person_ride1} = Rides.join_ride(ride.id, person1.id, :backseat)
      assert {:ok, _person_ride2} = Rides.join_ride(ride.id, person2.id, :backseat)
    end

    test "prevents joining when no seats of the desired type are available" do
      ride = generate(ride(seats: [:driver]))
      [person1, person2] = generate_many(person(), 2)

      # First person takes the driver seat
      Rides.join_ride!(ride.id, person1.id, :driver)

      # Second person should not be able to take the driver seat
      assert {:error, _} = Rides.join_ride(ride.id, person2.id, :driver)
    end

    test "prevents joining when seat type doesn't exist on the ride" do
      ride = generate(ride(seats: [:driver]))
      person = generate(person())

      assert {:error, _} = Rides.join_ride(ride.id, person.id, :nonexistent_seat)
    end

    test "allows joining when seat becomes available after someone leaves" do
      ride = generate(ride(seats: [:driver]))
      [person1, person2] = generate_many(person(), 2)

      # First person takes the driver seat
      {:ok, person_ride1} = Rides.join_ride(ride.id, person1.id, :driver)

      # Remove first person from the ride
      Ash.destroy!(person_ride1)

      # Second person should now be able to take the driver seat
      assert {:ok, _person_ride2} = Rides.join_ride(ride.id, person2.id, :driver)
    end

    test "works with complex seat configurations" do
      # Setup: Create ride with multiple single-seat types
      ride = generate(ride(seats: [:driver, :front_passenger, :backseat_left, :backseat_middle, :backseat_right]))
      
      people = generate_many(person(), 6)
      [p1, p2, p3, p4, p5, p6] = people

      # Action: Fill all available seats
      Rides.join_ride!(ride.id, p1.id, :driver)
      Rides.join_ride!(ride.id, p2.id, :front_passenger)
      Rides.join_ride!(ride.id, p3.id, :backseat_left)
      Rides.join_ride!(ride.id, p4.id, :backseat_middle)
      Rides.join_ride!(ride.id, p5.id, :backseat_right)

      # Verification: Sixth person should not be able to join any seat
      assert {:error, _} = Rides.join_ride(ride.id, p6.id, :driver)
      assert {:error, _} = Rides.join_ride(ride.id, p6.id, :front_passenger)
      assert {:error, _} = Rides.join_ride(ride.id, p6.id, :backseat_left)
      assert {:error, _} = Rides.join_ride(ride.id, p6.id, :backseat_middle)
      assert {:error, _} = Rides.join_ride(ride.id, p6.id, :backseat_right)
    end

    test "validates against current seat availability, not initial configuration" do
      ride = generate(ride(seats: [backseat: 3]))
      people = generate_many(person(), 4)
      [p1, p2, p3, p4] = people

      # Action: Take 2 of 3 backseat spots
      Rides.join_ride!(ride.id, p1.id, :backseat)
      Rides.join_ride!(ride.id, p2.id, :backseat)

      # Verification: Third person should still be able to join
      assert {:ok, _} = Rides.join_ride(ride.id, p3.id, :backseat)

      # Fourth person should be rejected
      assert {:error, _} = Rides.join_ride(ride.id, p4.id, :backseat)
    end
  end
end
