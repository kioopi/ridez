defmodule Ridez.Rides.Ride.Calculations.Seat do
  use Ash.Resource.Calculation

  require Ash.Query
  import Ash.Query, only: [filter: 2, load: 2]
  alias Ridez.Rides.PersonRide

  @impl true
  def init(opts) do
    {:ok, opts}
  end

  @impl true
  def load(_query, _opts, %{arguments: %{ride_id: rid}}) do
    [person_rides: filter(PersonRide, ride_id == ^rid) |> load(:seat)]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &get_seat/1)
  end

  defp get_seat(%{person_rides: []}), do: nil
  defp get_seat(%{person_rides: person_rides}), do: hd(person_rides).seat
end
