defmodule Ridez.Repo do
  use AshPostgres.Repo, otp_app: :ridez

  def min_pg_version do
    %Version{major: 17, minor: 5, patch: 0}
  end

  # Don't open unnecessary transactions
  # will default to `false` in 4.0
  def prefer_transaction? do
    false
  end

  def installed_extensions do
    # Add extensions here, and the migration generator will install them.
    ["ash-functions", Ridez.Extensions.LicenseValidation]
  end
end
