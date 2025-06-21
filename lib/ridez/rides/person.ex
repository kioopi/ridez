defmodule Ridez.Rides.Person do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  alias Ridez.Rides
  alias Rides.Ride
  alias Rides.PersonRide

  postgres do
    table "people"
    repo Ridez.Repo
  end

  actions do
    default_accept [:licences]

    defaults [:read, :create]
  end

  attributes do
    uuid_primary_key :id

    attribute :licences, {:array, :atom}, public?: true
  end

  relationships do
    many_to_many :rides, Ride do
      through PersonRide
    end

    has_many :person_rides, PersonRide, public?: true
  end

  calculations do
    calculate :seat, :atom, Ridez.Rides.Ride.Calculations.Seat do
      argument :ride_id, :uuid
      public? true
    end
  end
end
