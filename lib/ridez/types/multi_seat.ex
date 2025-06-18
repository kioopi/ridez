defmodule Ridez.Types.MultiSeat do
  use Ash.Type.NewType,
    subtype_of: :tuple,
    constraints: [
      fields: [
        seat: [
          type: :atom
          # allow_nil?: false
        ],
        amount: [
          type: :integer
          # allow_nil?: false,
          # constraints: [ min: 1 ]
        ]
      ]
    ]
end
