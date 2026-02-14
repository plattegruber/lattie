import Config

config :lattice,
  constitution_dir: "docs"

import_config "#{config_env()}.exs"
