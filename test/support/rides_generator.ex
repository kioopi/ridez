defmodule Ridez.Rides.Generator do
  use Ash.Generator

  alias Ridez.Rides.Ride
  alias Ridez.Rides.Person

  def ride(opts \\ []) do
    changeset_generator(
      Ride,
      :create,
      defaults: [
        seats:
          StreamData.map_of(
            StreamData.atom(:alphanumeric),
            StreamData.integer(1..10),
            min_length: 1,
            max_length: 5
          ),
        required_license: nil
      ],
      overrides: opts
    )
  end

  def person(opts \\ []) do
    changeset_generator(
      Person,
      :create,
      defaults: [],
      overrides: opts
    )
  end
end
