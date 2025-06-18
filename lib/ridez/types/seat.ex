defmodule Ridez.Types.Seat do
  use Ash.Type.NewType,
    subtype_of: :union,
    constraints: [
      types: [
        single: [type: :atom],
        multi: [
          type: :tuple
          # constraints: [instance_of: Ridez.Types.MultiSeat]
        ]
      ]
    ]
end
