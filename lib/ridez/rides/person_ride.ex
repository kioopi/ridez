defmodule Ridez.Rides.PersonRide do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  postgres do
    table "person_rides"
    repo Ridez.Repo
  end

  actions do
    defaults [:read, create: [:seat, :person_id, :ride_id]]
  end

  attributes do
    uuid_primary_key :id

    attribute :seat, :atom, allow_nil?: false, public?: true
  end

  relationships do
    belongs_to :ride, Ridez.Rides.Ride, allow_nil?: false, public?: true
    belongs_to :person, Ridez.Rides.Person, allow_nil?: false, public?: true
  end
end
