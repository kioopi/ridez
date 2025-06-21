defmodule Ridez.Ride.RideTest do
  use Ridez.DataCase

  import Ridez.Rides.Generator
  alias Ridez.Rides
  alias Rides.Ride
  alias Rides.PersonRide
  alias Ash.Changeset

  describe "Ride creation" do
    test "simple creation" do
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

    test "create ride with person" do
      person = generate(person())

      motorcycle =
        Changeset.for_create(Ride, :create, %{
          seats: [:driver, :backseat],
          people: [%{id: person.id, seat: :driver}]
        })
        |> Ash.create!()

      motorcycle =
        Ash.load!(motorcycle, [:available_seat_types, people: [seat: [ride_id: motorcycle.id]]])

      driver = hd(motorcycle.people)

      assert driver.id == person.id
      # seat is loaded
      assert driver.seat == :driver
      # available seats are correctly calculated
      assert motorcycle.available_seat_types == [:backseat]
    end

    test "create ride with person with shortened syntax" do
      person = generate(person())

      motorcycle =
        Changeset.for_create(Ride, :create, %{
          seats: [:driver, :backseat],
          people: [driver: person.id]
        })
        |> Ash.create!()

      motorcycle = Ash.load!(motorcycle, people: [seat: [ride_id: motorcycle.id]])

      driver = hd(motorcycle.people)

      assert driver.id == person.id
      assert driver.seat == :driver
    end

    test "when creating a ride with people, seats are auto added" do
      motorcycle =
        Changeset.for_create(Ride, :create, %{
          seats: [backseat: 3],
          people: [driver: generate(person()).id, shotgun: generate(person()).id]
        })
        |> Ash.create!()

      motorcycle =
        Ash.load!(motorcycle, [:available_seat_counts, people: [seat: [ride_id: motorcycle.id]]])

      assert motorcycle.seats == %{"driver" => 1, "shotgun" => 1, "backseat" => 3}
      assert motorcycle.available_seat_counts == %{"driver" => 0, "shotgun" => 0, "backseat" => 3}

      assert Enum.any?(motorcycle.people, fn p -> p.seat == :driver end)
      assert Enum.any?(motorcycle.people, fn p -> p.seat == :shotgun end)
    end

    test "explicit ammount of seats win over people" do
      people = generate_many(person(), 3)

      # when there is an explicit amount of seats set in the seats argument,
      # there can not be more pople than seats
      assert_raise Ash.Error.Invalid, fn ->
        Changeset.for_create(Ride, :create, %{
          seats: [bench: 2],
          people: Enum.map(people, &{:bench, &1.id})
        })
        |> Ash.create!()
      end
    end
  end

  describe "Ride calculations" do
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
