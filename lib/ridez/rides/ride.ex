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
      argument :seats, {:array, :term}
    end
  end

  changes do
    change Ridez.Changes.SeatsMap
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

  aggregates do
    list :taken_seats, :person_rides, field: :seat
    
  end
end
