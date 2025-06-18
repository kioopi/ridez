defmodule Ridez.Rides do
  use Ash.Domain,
    otp_app: :ridez

  resources do
    resource Ridez.Rides.Ride do
      define :create_ride, action: :create
    end

    resource Ridez.Rides.Person do
      define :create_person, action: :create
    end

    resource Ridez.Rides.PersonRide do
      define :join_ride, action: :create, args: [:ride_id, :person_id, :seat]
    end
  end
end
