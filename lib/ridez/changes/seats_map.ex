defmodule Ridez.Changes.SeatsMap do
  @moduledoc """
  A change that converts seats data into a standardized map format.

  This change takes seats data from the changeset arguments and normalizes it
  into a map where keys are seat types (atoms) and values are quantities (integers).

  ## Input formats supported:
  - Map: `%{economy: 2, business: 1}` - passed through unchanged
  - List of atoms: `[:economy, :business]` - converted to map with quantity 1 for each
  - Mixed list: `[:economy, business: 2]` - atoms default to quantity 1, tuples specify quantity


  The normalized seats map is then stored in the `:seats` attribute of the changeset.
  """
  use Ash.Resource.Change
  import Ash.Changeset, only: [get_argument_or_attribute: 2, force_change_attribute: 3]

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    seats = get_argument_or_attribute(changeset, :seats)
    force_change_attribute(changeset, :seats, seats_map(seats))
  end

  def seats_map(seats) when is_list(seats) do
    Map.new(seats, fn
      {seat, amount} when is_atom(seat) and is_integer(amount) -> {seat, amount}
      seat when is_atom(seat) -> {seat, 1}
    end)
  end

  def seats_map(seats), do: seats
end
