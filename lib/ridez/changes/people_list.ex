defmodule Ridez.Changes.PeopleList do
  @moduledoc """
  Normalizes the `:people` argument by converting tuple format `{seat, id}`
  to map format `%{id: id, seat: seat}` for consistent processing.
  """

  use Ash.Resource.Change
  import Ash.Changeset, only: [get_argument: 2, set_argument: 3]

  @impl true
  def init(opts), do: {:ok, opts}

  @impl true
  def change(changeset, _opts, _context) do
    case get_argument(changeset, :people) do
      nil -> changeset
      people -> set_argument(changeset, :people, people_list(people))
    end
  end

  def people_list(people) when is_list(people) do
    Enum.map(people, fn
      {seat, id} when is_atom(seat) and is_binary(id) -> %{id: id, seat: seat}
      person -> person
    end)
  end

  def people_list(people), do: people
end
