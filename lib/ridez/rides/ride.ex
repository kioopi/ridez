defmodule Ridez.Rides.Ride do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  alias Ridez.Rides.PersonRide
  alias Ridez.Rides.Person

  postgres do
    table "rides"
    repo Ridez.Repo
  end

  actions do
    defaults [:read]

    create :create do
      primary? true
      accept [:required_license]
      argument :seats, :term
      # {:array, :map} or {:array, :tuple}
      argument :people, :term

      # change to accept simplified seat defintion
      change Ridez.Changes.SeatsMap
      # change to accept simplified people definition
      change Ridez.Changes.PeopleList
      # change to update seats based on people
      change Ridez.Changes.PeopleSeats

      # validate seat availability
      validate Ridez.Validations.CreateRide

      change manage_relationship(:people, on_lookup: :relate, join_keys: [:seat])
    end
  end

  attributes do
    uuid_primary_key :id

    attribute :seats, :map, allow_nil?: false, public?: true
    attribute :required_license, :atom, public?: true
  end

  relationships do
    many_to_many :people, Person do
      through PersonRide
    end

    has_many :person_rides, PersonRide, public?: true
  end

  calculations do
    calculate :total_seat_types,
              {:array, :atom},
              {Ridez.Rides.Ride.Calculations.TotalSeatTypes, []}

    calculate :taken_seat_counts, :map, {Ridez.Rides.Ride.Calculations.TakenSeatCounts, []}

    calculate :available_seat_counts,
              :map,
              {Ridez.Rides.Ride.Calculations.AvailableSeatCounts, []}

    calculate :available_seat_types,
              {:array, :atom},
              {Ridez.Rides.Ride.Calculations.AvailableSeatTypes, []}

    calculate :occupied_seat_types,
              {:array, :atom},
              {Ridez.Rides.Ride.Calculations.OccupiedSeatTypes, []}

    calculate :has_available_seats?,
              :boolean,
              {Ridez.Rides.Ride.Calculations.HasAvailableSeats, []}
  end

  aggregates do
    list :taken_seats, :person_rides, field: :seat
  end
end
