defmodule Ridez.Rides.PersonRide do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  postgres do
    table "person_rides"
    repo Ridez.Repo
  end

  identities do
    identity :unique_person_per_ride, [:person_id, :ride_id] do
      eager_check? true
      message "Person is already on this ride"
    end
  end

  actions do
    defaults [:read, :destroy, create: [:seat, :person_id, :ride_id]]

    read :seat do
      argument :ride_id, :uuid, allow_nil?: false
      argument :person_id, :uuid, allow_nil?: false

      prepare build(select: [:seat])
    end
  end

  validations do
    validate {Ridez.Validations.SeatAvailable, []}
    validate {Ridez.Validations.RequiredLicense, []}
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
