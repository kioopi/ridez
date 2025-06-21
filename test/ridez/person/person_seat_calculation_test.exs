defmodule Ridez.Rides.PersonSeatCalculationTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Rides

  describe "Seat" do
    test "contains the seat atom of a person for a ride id" do
      person = generate(person())
      ride = generate(ride(seats: [:driver, :backseat]))

      Rides.join_ride!(ride.id, person.id, :backseat)

      assert Ash.load!(person, seat: [ride_id: ride.id]).seat == :backseat
    end

    test "contains nil when person does not have a seat on the ride" do
      person = generate(person())
      ride = generate(ride(seats: [:driver, :backseat]))

      assert Ash.load!(person, seat: [ride_id: ride.id]).seat == nil
    end

    test "works when person has more rides" do
      person = generate(person())

      generate(
        ride(
          seats: [:couch],
          people: [%{id: person.id, seat: :couch}]
        )
      )

      ride =
        generate(
          ride(
            seats: [:driver, :backseat],
            people: [%{id: person.id, seat: :driver}]
          )
        )

      generate(
        ride(
          seats: [:chair],
          people: [%{id: person.id, seat: :chair}]
        )
      )

      assert Ash.load!(person, seat: [ride_id: ride.id]).seat == :driver
    end

    test "works with other people on the ride" do
      [person, other1, other2] = generate_many(person(), 3)

      ride =
        generate(
          ride(
            seats: [:driver, backseat: 2],
            people: [
              %{id: person.id, seat: :driver},
              %{id: other1.id, seat: :backseat},
              %{id: other2.id, seat: :backseat}
            ]
          )
        )

      assert Ash.load!(person, seat: [ride_id: ride.id]).seat == :driver
    end
  end
end
