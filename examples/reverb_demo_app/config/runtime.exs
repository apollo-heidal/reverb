import Config

if source = System.get_env("REVERB_DEMO_SOURCE") do
  config :reverb_demo_app, :source_name, source
end
