# Ridez

A demo application showcasing **many-to-many relationships with extra fields** in [Ash Framework](https://ash-hq.org/).

## What is Ridez?

Ridez is not a real ride-sharing application—it's a learning project designed to illustrate advanced relationship patterns in Ash Framework. The core challenge it solves is tracking not just *who* is in each ride, but *where they sit*, along with license requirements the drivers seat.

### Key Features Demonstrated

- **Flexible seat management**: Rides can have different seat types (`:driver`, `:backseat`, `:window`) with varying quantities
- **Join tables with extra fields**: The `PersonRide` resource tracks seat assignments as extra data on the relationship
- **Cross-resource validations**: License requirements ensure only qualified people can take driver seats
- **Smart calculations**: Real-time seat availability, taken counts, and person-specific seat lookups
- **Developer-friendly APIs**: Clean domain interfaces that hide complexity

### Why This Exists

This repository serves as a reference for implementing relationship patterns in Ash Framework. The patterns demonstrated here apply to many domains:

- Event attendees with roles
- Product orders with quantities
- Team members with positions
- Course enrollments with grades
- Social connections with relationship types

## Tutorial

📖 **[Tutorial: Many-to-Many Relationships with Extra Fields](tutorial.md)**

The tutorial walks through the entire implementation, covering:

1. Problem analysis and domain modeling
2. Resource and schema design
3. Relationship configuration
4. Business logic and validations
5. Calculations and aggregates
6. API design and developer experience
7. Querying patterns and usage
8. Testing strategies
9. Best practices and lessons learned

## Quick Start

```bash
# Clone and setup
git clone <repo-url>
cd ridez
mix setup

# Run tests
mix test

# Explore in IEx
iex -S mix
```

## Architecture Overview

```
Ride ←→ PersonRide ←→ Person
     ↘      ↙
       seat (extra field)
```

- **`Ride`**: Main entity with flexible seat configuration (`%{driver: 1, backseat: 2}`)
- **`Person`**: Users with license information (`[:car, :motorcycle]`)
- **`PersonRide`**: Join resource with seat assignment (`:driver`, `:backseat`, etc.)

## Inspiration

The name "Ridez" pays homage to the "Tunez" application from the excellent book [*"Ash Framework - Create Declarative Elixir Web Apps"*](https://pragprog.com/titles/ash/ash-framework/) by Rebecca Le and Zach Daniel.
