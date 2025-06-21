defmodule Ridez.Changes.PeopleSeats do
  @moduledoc """
  An Ash resource change that automatically manages seat allocation based on people assignments.

  When a changeset includes a `people` argument, this change will:

  1. Extract the seat assignments from each person in the list
  2. Calculate the required seat counts by seat type
  3. Update the resource's `seats` attribute to ensure minimum seat availability

  The change uses `Map.put_new/3` to add seats, meaning it will only add seats if they don't
  already exist in the seats map. This prevents overriding existing explicit seat configurations
  while ensuring that implicitly required seats are available.
  """
  use Ash.Resource.Change
  import Ash.Changeset, only: [get_attribute: 2, get_argument: 2, force_change_attribute: 3]

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    seats = get_attribute(changeset, :seats)

    case get_argument(changeset, :people) do
      nil -> changeset
      people -> force_change_attribute(changeset, :seats, add_seats_from_people(seats, people))
    end
  end

  def required_seats(people) do
    Enum.reduce(people, %{}, fn %{seat: seat}, acc ->
      Map.update(acc, seat, 1, &(&1 + 1))
    end)
  end

  defp add_seats_from_people(seats, people) do
    Enum.reduce(required_seats(people), seats || %{}, fn {seat, count}, seats ->
      Map.put_new(seats, seat, count)
    end)
  end
end
