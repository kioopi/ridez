defmodule Ridez.Rides.Person do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  postgres do
    table "people"
    repo Ridez.Repo
  end

  actions do
    defaults [:read, :create]
  end

  attributes do
    uuid_primary_key :id

    attribute :licences, {:array, :atom}, public?: true
  end
end
