# frozen_string_literal: true

# PublicActivity configuration
PublicActivity.configure do |config|
  # Set this to true to enable ActiveRecord adapter
  config.orm = :active_record

  # Set this to true to enable table name prefix
  config.table_name_prefix = nil

  # Set this to true to enable table name suffix
  config.table_name_suffix = nil
end

# Customize PublicActivity to use JSONB for parameters
# PublicActivity by default uses YAML, but we're using JSONB
# We'll handle serialization in the Activity model

