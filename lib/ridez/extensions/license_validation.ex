defmodule Ridez.Extensions.LicenseValidation do
  @moduledoc """
  Custom PostgreSQL extension for enforcing license validation at the database level.

  This extension creates a trigger that validates driver seat assignments,
  ensuring only people with the required license can take the driver seat.
  """

  use AshPostgres.CustomExtension,
    name: "license_validation",
    latest_version: 1

  @impl true
  def install(_version) do
    ~s|
    execute("""
    #{install_sql()}
    """)

     # Create the trigger on person_rides table
    execute("""
    CREATE TRIGGER validate_driver_license_trigger
      BEFORE INSERT OR UPDATE ON person_rides
      FOR EACH ROW
      EXECUTE FUNCTION validate_driver_license_trigger();
    """)

    # Add comments for people exploring the db
    execute("""
    COMMENT ON FUNCTION validate_driver_license_trigger() IS
    'Validates that only people with the required license can take the driver seat in a ride';
    """)
    |
  end

  @impl true
  def uninstall(_version) do
    ~s|
    execute("""
    DROP TRIGGER IF EXISTS validate_driver_license_trigger ON person_rides;
    """)

    execute("""
    DROP FUNCTION IF EXISTS validate_driver_license_trigger();
    """)
    |
  end

  defp install_sql do
    File.read!(
      Path.join([
        Application.app_dir(:ridez),
        "priv",
        "repo",
        "extensions",
        "license_validation_trigger.sql"
      ])
    )
  rescue
    # Fallback for development/test environments where app_dir might not be available
    File.Error ->
      File.read!("priv/repo/extensions/license_validation_trigger.sql")
  end
end
