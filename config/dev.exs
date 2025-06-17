import Config

config :ridez, Ridez.Repo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "ridez_dev",
  show_sensitive_data_on_connection_error: true,
  pool_size: 10
