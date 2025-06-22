# Many-to-Many Relationships with Extra Fields in Ash Framework

*A tutorial using the Ridez ride-sharing application*

Ridez is not a real application, just a way to illustrate the concepts.
I mostly wrote it to learn about many-to-many with extra fields on the join resource. As a reference for myself.
This tutorial is written by Claude Code (claude.ai/code) based on the code. It seems to have done a reasonably well job.

The name Ridez was chosen because of the Tunez app that is the example application in the book "Ash Framework - Create Declarative Elixir Web Apps" by Rebecca Le and Zach Daniel.

The idea is to have Rides that have a seats of different types, like `:driver`, `:backseat` with different quantities, like `%{driver: 1, backseat: 3}`.
When adding people to rides, we need to know which seat they occupy, so we have a join resource `PersonRide` that has an extra field `seat` to track this.
The second feature is that the :driver seat may require a license only licensed drivers can take the driver seat, so we have a `required_license` field on the `Ride` resource and a `licences` field on the `Person` resource to track what licenses a person has.

## Table of Contents

1. [The Problem: More Than Just Relationships](#1-the-problem-more-than-just-relationships)
2. [Building the Foundation: Resources and Schema Design](#2-building-the-foundation-resources-and-schema-design)
3. [Connecting Everything: Relationship Configuration](#3-connecting-everything-relationship-configuration)
4. [Business Logic: Validations and Constraints](#4-business-logic-validations-and-constraints)
5. [Smart Calculations: Making Data Useful](#5-smart-calculations-making-data-useful)
6. [Developer Experience: Creating a Clean API](#6-developer-experience-creating-a-clean-api)
7. [Querying and Using the System](#7-querying-and-using-the-system)
8. [Testing Strategies](#8-testing-strategies)
9. [Lessons Learned and Best Practices](#9-lessons-learned-and-best-practices)

---

## 1. The Problem: More Than Just Relationships

**What you'll learn**: Why standard many-to-many relationships aren't enough and how Ash solves this problem.

### 1.1 The Ridez Domain Model

In many applications, a simple many-to-many relationship isn't enough. Consider our ride-sharing scenario:

- **Rides** have multiple **People**
- **People** can be in multiple **Rides**
- But here's the key: we need to know **which seat** each person occupies

A standard many-to-many relationship can tell us *who* is in a ride, but not *where* they're sitting. This is where join tables with extra fields become essential.

Our domain consists of three core resources:

1. **`Ride`** ([lib/ridez/rides/ride.ex](lib/ridez/rides/ride.ex)) - The main ride entity
2. **`Person`** ([lib/ridez/rides/person.ex](lib/ridez/rides/person.ex)) - Users/passengers
3. **`PersonRide`** ([lib/ridez/rides/person_ride.ex](lib/ridez/rides/person_ride.ex)) - The join table with seat information

#### Understanding Seat Management

Our seat system supports flexible configurations:
- Different seat types: `:driver`, `:backseat`, `:window`, etc.
- Variable quantities per type: `%{driver: 1, backseat: 3, window: 2}`
- License requirements for certain seats (e.g., only licensed drivers can take the driver seat)

---

## 2. Building the Foundation: Resources and Schema Design

**What you'll learn**: How to structure your resources and define the database schema for many-to-many relationships with extra fields.

### 2.1 The Ride Resource

*Source: [lib/ridez/rides/ride.ex](lib/ridez/rides/ride.ex)*

The `Ride` resource is our central entity with flexible seat configuration:

```elixir
defmodule Ridez.Rides.Ride do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Flexible seat configuration as a map
    # Example: %{driver: 1, backseat: 2, window: 2}
    attribute :seats, :map, allow_nil?: false, public?: true

    # Optional license requirement for driver seats
    attribute :required_license, :atom, public?: true
  end

  # ... relationships and other configuration
end
```

The `seats` attribute uses a map structure where:
- **Keys** are seat types (atoms like `:driver`, `:backseat`)
- **Values** are quantities (integers representing how many of each seat type)

The `required_license` field enforces business rules - for example, requiring a `:motorcycle` license to drive certain rides.

### 2.2 The Person Resource

*Source: [lib/ridez/rides/person.ex](lib/ridez/rides/person.ex)*

The `Person` resource represents users and passengers:

```elixir
defmodule Ridez.Rides.Person do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # Array of license types this person holds
    # Example: [:car, :motorcycle, :truck]
    attribute :licences, {:array, :atom}, public?: true
  end

  # ... relationships and calculations
end
```

The `licences` attribute stores an array of license types the person holds, enabling license validation logic.

### 2.3 The PersonRide Join Resource

*Source: [lib/ridez/rides/person_ride.ex](lib/ridez/rides/person_ride.ex)*

This is where the magic happens - our join table with extra fields:

```elixir
defmodule Ridez.Rides.PersonRide do
  use Ash.Resource, otp_app: :ridez, domain: Ridez.Rides, data_layer: AshPostgres.DataLayer

  attributes do
    uuid_primary_key :id

    # The crucial extra field - which seat this person occupies
    attribute :seat, :atom, allow_nil?: false, public?: true
  end

  relationships do
    # Links to both parent resources
    belongs_to :ride, Ridez.Rides.Ride, allow_nil?: false, public?: true
    belongs_to :person, Ridez.Rides.Person, allow_nil?: false, public?: true
  end

  # Ensure each person can only be in each ride once
  identities do
    identity :unique_person_per_ride, [:person_id, :ride_id] do
      eager_check? true
      message "Person is already on this ride"
    end
  end
end
```

Key design decisions:
- **`seat` attribute**: The extra field that makes this more than a simple join
- **`belongs_to` relationships**: Connect to both parent resources
- **Unique identity**: Prevents duplicate person-ride combinations

---

## 3. Connecting Everything: Relationship Configuration

**What you'll learn**: How to properly configure many-to-many relationships using a join resource in Ash Framework.

### 3.1 Setting Up Many-to-Many Through Relationships

Both `Ride` and `Person` need many-to-many relationships that go through our join resource:

**In the Ride resource:**
```elixir
relationships do
  many_to_many :people, Person do
    through PersonRide
  end

  # Direct access to join records when needed
  has_many :person_rides, PersonRide, public?: true
end
```

**In the Person resource:**
```elixir
relationships do
  many_to_many :rides, Ride do
    through PersonRide
  end

  # Direct access to join records when needed
  has_many :person_rides, PersonRide, public?: true
end
```

### 3.2 Understanding the Relationship Flow

Here's how the relationships work together:

```
Ride ←→ PersonRide ←→ Person
```

- **many_to_many**: Provides convenient access to related records across the join
- **has_many**: Gives direct access to join records (essential for seat assignments)
- **through PersonRide**: Tells Ash which resource to use as the join table

### 3.3 Loading Related Data

With these relationships, you can load data in multiple ways:

```elixir
# Load people in a ride (via many-to-many)
ride = Ash.load!(ride, :people)

# Load join records with seat information (via has_many)
ride = Ash.load!(ride, :person_rides)

# Load both for complete information
ride = Ash.load!(ride, [:people, :person_rides])
```

---

## 4. Business Logic: Validations and Constraints

**What you'll learn**: How to implement business rules that span across your many-to-many relationships.

### 4.1 Seat Availability Validation

*Source: [lib/ridez/validations/seat_available.ex](lib/ridez/validations/seat_available.ex)*

This validation ensures seats exist and are available before assignment:

```elixir
defmodule Ridez.Validations.SeatAvailable do
  use Ash.Resource.Validation

  @impl true
  def validate(changeset, _opts, _context) do
    seat = Changeset.get_attribute(changeset, :seat)
    ride_id = Changeset.get_attribute(changeset, :ride_id)

    if seat && ride_id do
      case Ash.get(Ride, ride_id, load: [:available_seat_counts]) do
        {:ok, ride} ->
          validate_seat_availability(seat, ride)
        {:error, _} ->
          {:error, "Unable to load ride information"}
      end
    else
      :ok
    end
  end

  defp validate_seat_availability(seat, ride) do
    seat_string = to_string(seat)
    available_counts = ride.available_seat_counts || %{}

    case Map.get(available_counts, seat_string) do
      nil -> {:error, "Seat type '#{seat}' does not exist on this ride"}
      0 -> {:error, "No seats of type '#{seat}' are available on this ride"}
      count when count > 0 -> :ok
    end
  end
end
```

**Key techniques:**
- **Loading calculations**: Uses `load: [:available_seat_counts]` to get real-time availability
- **Cross-resource validation**: Validates join table data against parent resource constraints
- **Meaningful errors**: Provides specific feedback about why seat assignment failed

### 4.2 License Requirements Validation

*Source: [lib/ridez/validations/required_license.ex](lib/ridez/validations/required_license.ex)*

This validation ensures people have required licenses for certain seats (like driver seats):

```elixir
def validate(changeset, _opts, _context) do
  seat = Changeset.get_attribute(changeset, :seat)

  # Only validate driver seats
  if seat == :driver do
    person_id = Changeset.get_attribute(changeset, :person_id)
    ride_id = Changeset.get_attribute(changeset, :ride_id)

    with {:ok, person} <- Ash.get(Person, person_id),
         {:ok, ride} <- Ash.get(Ride, ride_id) do
      validate_license_requirement(person, ride)
    end
  else
    :ok  # Non-driver seats don't require license validation
  end
end
```

### 4.3 Database-Level Constraints

The unique identity in PersonRide prevents duplicate assignments:

```elixir
identities do
  identity :unique_person_per_ride, [:person_id, :ride_id] do
    eager_check? true
    message "Person is already on this ride"
  end
end
```

This works at both the application level (`eager_check? true`) and database level (unique index), providing defense in depth.

---

## 5. Smart Calculations: Making Data Useful

**What you'll learn**: How to build calculations that provide insights into your many-to-many relationships.

### 5.1 Aggregating Join Table Data

The `Ride` resource uses aggregates to collect data from join records:

```elixir
aggregates do
  # Collect all taken seats as a list
  list :taken_seats, :person_rides, field: :seat
end
```

This aggregate gives us `["driver", "backseat", "backseat"]` - a list of all occupied seats.

### 5.2 Seat Management Calculations

#### Available Seat Counts

*Source: [lib/ridez/rides/ride/calculations/available_seat_counts.ex](lib/ridez/rides/ride/calculations/available_seat_counts.ex)*

This calculation computes real-time seat availability:

```elixir
def calculate(records, _opts, _context) do
  Enum.map(records, fn record ->
    # Get total seats: %{driver: 1, backseat: 3}
    total_seats = record.seats || %{}

    # Get taken seats: %{"driver" => 1, "backseat" => 2}
    taken_seats = record.taken_seat_counts || %{}

    # Calculate available for each seat type
    total_seats
    |> Enum.into(%{}, fn {seat_type, total_count} ->
      seat_string = to_string(seat_type)
      taken_count = Map.get(taken_seats, seat_string, 0)
      available_count = max(0, total_count - taken_count)
      {seat_string, available_count}
    end)
  end)
end
```

**Usage example:**
```elixir
ride = Ash.load!(ride, [:available_seat_counts])
ride.available_seat_counts
# => %{"driver" => 0, "backseat" => 1, "window" => 2}
```

#### Other Useful Calculations

```elixir
calculations do
  # List of seat types that still have availability
  calculate :available_seat_types, {:array, :atom},
    {Ridez.Rides.Ride.Calculations.AvailableSeatTypes, []}

  # Quick boolean check for any availability
  calculate :has_available_seats?, :boolean,
    {Ridez.Rides.Ride.Calculations.HasAvailableSeats, []}
end
```

### 5.3 Person-Specific Calculations

*Source: [lib/ridez/rides/ride/calculations/seat.ex](lib/ridez/rides/ride/calculations/seat.ex)*

The `seat` calculation finds a person's seat in a specific ride:

```elixir
defmodule Ridez.Rides.Ride.Calculations.Seat do
  use Ash.Resource.Calculation

  @impl true
  def load(_query, _opts, %{arguments: %{ride_id: ride_id}}) do
    [person_rides: filter(PersonRide, ride_id == ^ride_id)]
  end

  @impl true
  def calculate(records, _opts, _context) do
    Enum.map(records, &get_seat/1)
  end

  defp get_seat(%{person_rides: []}), do: nil
  defp get_seat(%{person_rides: [person_ride | _]}), do: person_ride.seat
end
```

**Usage:**
```elixir
person = Ash.load!(person, [seat: %{ride_id: ride.id}])
person.seat  # => :driver or :backseat or nil
```

---

## 6. Developer Experience: Creating a Clean API

**What you'll learn**: How to build convenient interfaces for managing many-to-many relationships with extra fields.

### 6.1 Data Transformation with Changes

#### SeatsMap Change

*Source: [lib/ridez/changes/seats_map.ex](lib/ridez/changes/seats_map.ex)*

This change normalizes different seat input formats:

```elixir
def seats_map(seats) when is_list(seats) do
  Map.new(seats, fn
    {seat, amount} when is_atom(seat) and is_integer(amount) -> {seat, amount}
    seat when is_atom(seat) -> {seat, 1}
  end)
end
```

**Supported input formats:**
```elixir
# List of atoms (defaults to quantity 1)
[:driver, :backseat]
# => %{driver: 1, backseat: 1}

# Mixed list with quantities
[:driver, backseat: 2, window: 3]
# => %{driver: 1, backseat: 2, window: 3}

# Already a map (passed through)
%{driver: 1, backseat: 2}
# => %{driver: 1, backseat: 2}
```

### 6.2 Managing Relationships Through Parent Resources

The `Ride` create action demonstrates sophisticated relationship management:

```elixir
create :create do
  accept [:required_license]
  argument :seats, :term
  argument :people, :term

  # Normalize input data
  change Ridez.Changes.SeatsMap
  change Ridez.Changes.PeopleList
  change Ridez.Changes.PeopleSeats

  # Create ride with people in one operation
  change manage_relationship(:people, on_lookup: :relate, join_keys: [:seat])
end
```

**Usage example:**
```elixir
Rides.create_ride(%{
  seats: [:driver, :backseat],
  people: [%{id: person_id, seat: :driver}],
  required_license: :car
})
```

This creates the ride and assigns people to seats in a single atomic operation.

### 6.3 Domain Interface Design

*Source: [lib/ridez/rides.ex](lib/ridez/rides.ex)*

The domain provides clean, intuitive interfaces:

```elixir
defmodule Ridez.Rides do
  use Ash.Domain, otp_app: :ridez

  resources do
    resource Ridez.Rides.Ride do
      define :create_ride, action: :create
    end

    resource Ridez.Rides.Person do
      define :create_person, action: :create
    end

    resource Ridez.Rides.PersonRide do
      define :join_ride, action: :create, args: [:ride_id, :person_id, :seat]
      define :get_seat, action: :seat, get?: true, args: [:ride_id, :person_id]
    end
  end
end
```

**Clean API usage:**
```elixir
# Create resources
{:ok, ride} = Rides.create_ride(%{seats: [:driver, :backseat]})
{:ok, person} = Rides.create_person(%{licences: [:car]})

# Assign seat
{:ok, person_ride} = Rides.join_ride(ride.id, person.id, :driver)

# Query seat assignment
{:ok, seat} = Rides.get_seat(ride.id, person.id)
```

---

## 7. Querying and Using the System

**What you'll learn**: How to effectively query and work with your many-to-many relationships.

### 7.1 Loading Relationships and Calculations

**Complete ride information:**
```elixir
ride = Ash.load!(ride, [
  :people,                    # Who's in the ride
  :person_rides,             # Seat assignments
  :taken_seats,              # Aggregate of occupied seats
  :available_seat_counts,    # Real-time availability
  :available_seat_types,     # Which types are bookable
  :has_available_seats?      # Quick availability check
])
```

**Efficient loading strategies:**
```elixir
# Load multiple rides with their people
rides = Ash.load!(rides, [:people, :available_seat_counts])

# Load a person's seat in specific rides
person = Ash.load!(person, [
  :rides,
  seat: %{ride_id: ride.id}
])
```

### 7.2 Direct Join Table Access

**Seat assignment workflow:**
```elixir
# Check availability first
ride = Ash.load!(ride, [:available_seat_types])

if :driver in ride.available_seat_types do
  # Assign the seat
  case Rides.join_ride(ride.id, person.id, :driver) do
    {:ok, person_ride} ->
      # Success! Person is now the driver
    {:error, error} ->
      # Handle validation errors (no license, seat taken, etc.)
  end
end
```

**Query seat assignments:**
```elixir
# Get a specific person's seat
{:ok, seat} = Rides.get_seat(ride.id, person.id)

# Get all seat assignments for a ride
ride = Ash.load!(ride, :person_rides)
seat_assignments = ride.person_rides
```

### 7.3 Real-World Query Patterns

**Finding rides with available seats:**
```elixir
# Rides that have any available seats
available_rides =
  Ash.read!(Ride)
  |> Ash.load!([:has_available_seats?])
  |> Enum.filter(& &1.has_available_seats?)

# Rides with specific seat types available
driver_needed_rides =
  Ash.read!(Ride)
  |> Ash.load!([:available_seat_types])
  |> Enum.filter(&(:driver in &1.available_seat_types))
```

**Checking if a person can join a ride:**
```elixir
def can_person_join_ride?(person, ride, seat_type) do
  ride = Ash.load!(ride, [:available_seat_types, :required_license])

  # Check seat availability
  seat_available? = seat_type in ride.available_seat_types

  # Check license requirement (for driver seats)
  license_ok? =
    if seat_type == :driver and ride.required_license do
      ride.required_license in person.licences
    else
      true
    end

  seat_available? and license_ok?
end
```

---

## 8. Testing Strategies

**What you'll learn**: How to effectively test many-to-many relationships with extra fields.

### 8.1 Test Data Generation

*Source: [test/support/rides_generator.ex](test/support/rides_generator.ex)*

Use Ash generators for realistic test data:

```elixir
defmodule Ridez.Rides.Generator do
  use Ash.Generator

  def ride(opts \\ []) do
    changeset_generator(
      Ride,
      :create,
      defaults: [
        seats: StreamData.map_of(
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
```

**Usage in tests:**
```elixir
test "person can join ride with available seats" do
  ride = generate(ride(seats: [:driver, :backseat]))
  person = generate(person(licences: [:car]))

  assert {:ok, _} = Rides.join_ride(ride.id, person.id, :driver)
end
```

### 8.2 Testing Validations

*Example from validation tests:*

```elixir
test "prevents person without required license from taking driver seat" do
  ride = generate(ride(seats: [:driver, :backseat], required_license: :motorcycle))
  person = generate(person(licences: [:car]))  # Wrong license type

  assert {:error, _} = Rides.join_ride(ride.id, person.id, :driver)
end

test "allows person with required license to take driver seat" do
  ride = generate(ride(seats: [:driver, :backseat], required_license: :motorcycle))
  person = generate(person(licences: [:motorcycle]))  # Correct license

  assert {:ok, _} = Rides.join_ride(ride.id, person.id, :driver)
end
```

### 8.3 Integration Testing

**End-to-end workflow testing:**
```elixir
test "complete ride booking workflow" do
  # Create ride with multiple seat types
  {:ok, ride} = Rides.create_ride(%{
    seats: [driver: 1, backseat: 2, window: 2],
    required_license: :car
  })

  # Create people with different licenses
  {:ok, driver} = Rides.create_person(%{licences: [:car]})
  {:ok, passenger1} = Rides.create_person(%{licences: []})
  {:ok, passenger2} = Rides.create_person(%{licences: []})

  # Assign seats
  {:ok, _} = Rides.join_ride(ride.id, driver.id, :driver)
  {:ok, _} = Rides.join_ride(ride.id, passenger1.id, :backseat)
  {:ok, _} = Rides.join_ride(ride.id, passenger2.id, :window)

  # Verify final state
  ride = Ash.load!(ride, [:people, :available_seat_counts])
  assert length(ride.people) == 3
  assert ride.available_seat_counts["backseat"] == 1
  assert ride.available_seat_counts["window"] == 1
  assert ride.available_seat_counts["driver"] == 0
end
```

---

## 9. Lessons Learned and Best Practices

**What you'll learn**: Key takeaways and patterns for your own applications.

### 9.1 Design Principles

**When to use join tables with extra fields:**
- ✅ When the relationship itself has attributes (seat assignments, roles, quantities)
- ✅ When you need to track relationship history or metadata
- ✅ When business rules depend on the relationship context

**Keep validations close to the data:**
- Put join table validations on the join resource
- Cross-resource validations should load minimal necessary data
- Use calculations for complex business logic checks

**Build calculations that tell a story:**
- `available_seat_counts` tells "how many seats are free"
- `has_available_seats?` tells "can I book this ride"
- `seat` tells "where does this person sit"

### 9.2 Performance Considerations

**Efficient loading strategies:**
```elixir
# ✅ Good: Load what you need upfront
rides = Ash.load!(rides, [:people, :available_seat_counts])

# ❌ Avoid: Loading relationships in loops (N+1 queries)
for ride <- rides do
  Ash.load!(ride, :people)  # This creates N queries!
end
```

**When to use aggregates vs calculations:**
- **Aggregates**: Simple data collection from related records (`list :taken_seats`)
- **Calculations**: Complex logic, cross-resource computations (`available_seat_counts`)

**Caching strategies:**
- Use Ash's built-in calculation caching for expensive computations
- Consider read-through caches for frequently accessed availability data
- Cache seat availability at the application level for high-traffic scenarios

### 9.3 Developer Experience

**Creating intuitive APIs:**
```elixir
# ✅ Clear, purpose-driven functions
Rides.join_ride(ride_id, person_id, seat_type)
Rides.get_seat(ride_id, person_id)

# ❌ Generic, unclear functions
PersonRide.create(%{ride_id: ..., person_id: ..., seat: ...})
```

**Flexible input handling:**
```elixir
# Support multiple input formats
seats: [:driver, :backseat]           # Simple list
seats: [driver: 1, backseat: 2]       # With quantities
seats: %{driver: 1, backseat: 2}      # Already normalized
```

**Clear error messages:**
```elixir
# ✅ Helpful error messages
"No seats of type 'driver' are available on this ride"
"Person does not have required license 'motorcycle' for driver seat"

# ❌ Generic error messages
"Validation failed"
"Invalid seat assignment"
```

---

## Conclusion

By the end of this tutorial, you have a deep understanding of how to implement sophisticated many-to-many relationships in Ash Framework. The patterns you've learned with Ridez—from flexible seat management to intuitive APIs—can be applied to any domain where relationships need to carry additional information:

- **Event attendees** with roles (speaker, attendee, organizer)
- **Product orders** with quantities and customizations
- **Team members** with positions and permissions
- **Course enrollments** with grades and completion status
- **Social connections** with relationship types and privacy settings

### Key Takeaways

1. **Join resources with extra fields** solve complex relationship requirements
2. **Thoughtful validation design** ensures data integrity across resources
3. **Smart calculations** make your data queryable and useful
4. **Developer-friendly APIs** hide complexity behind clean interfaces
5. **Comprehensive testing** ensures reliability in complex relationship scenarios

The Ash Framework's declarative approach makes these patterns accessible and maintainable, letting you focus on your domain logic rather than relationship management boilerplate.

---

## Additional Resources

- [Ash Framework Documentation](https://hexdocs.pm/ash/Ash.html)
- [AshPostgres Documentation](https://hexdocs.pm/ash_postgres/AshPostgres.html)
- [Ash Framework Book](https://pragprog.com/titles/ash/ash-framework/) by Rebecca Le and Zach Daniel
- [Ash Community Forum](https://elixirforum.com/c/ash-framework/123)

### Source Code References

All code examples in this tutorial come from the Ridez application:

- **Resources**: [`lib/ridez/rides/`](lib/ridez/rides/)
- **Validations**: [`lib/ridez/validations/`](lib/ridez/validations/)
- **Changes**: [`lib/ridez/changes/`](lib/ridez/changes/)
- **Calculations**: [`lib/ridez/rides/ride/calculations/`](lib/ridez/rides/ride/calculations/)
- **Tests**: [`test/ridez/`](test/ridez/)
- **Domain**: [`lib/ridez/rides.ex`](lib/ridez/rides.ex)
