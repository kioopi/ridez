defmodule Ridez.Application do
  @moduledoc false

  use Application

  @impl true
  def start(_type, _args) do
    children = [Ridez.Repo]

    opts = [strategy: :one_for_one, name: Ridez.Supervisor]
    Supervisor.start_link(children, opts)
  end
end
