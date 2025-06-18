defmodule Ridez.Ride.RideTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Rides
  alias Rides.Ride
  alias Rides.PersonRide
  alias Ash.Changeset

  describe "Ride" do
    test "creation" do
      motorcycle =
        Changeset.for_create(Ride, :create, %{
          seats: [:driver, :backseat],
          required_license: :motorcycle
        })
        |> Ash.create!()

      assert motorcycle.seats["driver"] == 1
      assert motorcycle.required_license == :motorcycle
    end

    test "create a PersonRide directly" do
      person = generate(person())
      ride = generate(ride())

      seat = ride.seats |> Map.keys() |> Enum.random()

      Changeset.for_create(PersonRide, :create, %{
        person_id: person.id,
        ride_id: ride.id,
        seat: seat
      })
      |> Ash.create!()

      ride = Ash.load!(ride, [:people])

      assert hd(ride.people).id == person.id
    end

    test "list taken seats of a ride" do
      ride = generate(ride(seats: %{driver: 1, backseat: 1}))
      person = generate(person())

      Rides.join_ride!(ride.id, person.id, :backseat)

      ride = Ash.load!(ride, [:taken_seats])

      assert ride.taken_seats == [:backseat]
    end

    test "list available seat types of a ride" do
      ride = generate(ride(seats: %{driver: 1, backseat: 1}))
      person = generate(person())

      Rides.join_ride!(ride.id, person.id, :backseat)

      ride = Ash.load!(ride, [:available_seat_types])

      assert ride.available_seat_types == [:driver]
    end
  end
end
