# frozen_string_literal: true

# PublicActivity configuration
# PublicActivity 3.0.1 works out of the box with ActiveRecord
# No explicit configuration needed - it automatically uses ActiveRecord as the ORM

# Customize PublicActivity to use JSONB for parameters
# PublicActivity by default uses YAML, but we're using JSONB
# We handle serialization in the Activity model by overriding the parameters method
