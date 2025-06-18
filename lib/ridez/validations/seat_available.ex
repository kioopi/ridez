defmodule Ridez.Validations.SeatAvailable do
  use Ash.Resource.Validation

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def validate(changeset, _opts, _context) do
    PersonRide
    |> Ash.Query.filter(id == ^Ash.Changeset.get_attribute(changeset, :ride_id))
    |> Ash.Query.select([:seat])
    |> Ash.Query.lock(:for_update)
    |> Ash.read_one!()
  end
end
