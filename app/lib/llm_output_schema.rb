# frozen_string_literal: true

require "json"

# LLM Output Schema
#
# Defines and validates standardized output schemas for LLM responses.
# Ensures deterministic behavior by enforcing structure and validation.
#
# Usage:
#   schema = LlmOutputSchema.for_type(:work_items)
#   validated = schema.validate_and_normalize(llm_response)
#
class LlmOutputSchema
  class ValidationError < StandardError; end

  # Schema definitions for each response type
  SCHEMAS = {
    work_items: {
      type: "object",
      required: ["type", "work_items"],
      properties: {
        type: { type: "string", enum: ["work_items"] },
        work_items: {
          type: "array",
          items: {
            type: "object",
            required: ["work_type", "agent_key"],
            properties: {
              work_type: { type: "string" },
              agent_key: { type: "string" },
              priority: { type: "integer", minimum: 1, maximum: 10, default: 5 },
              payload: { type: "object", default: {} }
            }
          }
        }
      }
    },
    file_writes: {
      type: "object",
      required: ["type", "files"],
      properties: {
        type: { type: "string", enum: ["file_writes"] },
        files: {
          type: "array",
          items: {
            type: "object",
            required: ["path", "content"],
            properties: {
              path: { type: "string" },
              content: { type: "string" }
            }
          }
        }
      }
    },
    github_operations: {
      type: "object",
      required: ["type", "operations"],
      properties: {
        type: { type: "string", enum: ["github_operations"] },
        operations: {
          type: "array",
          items: {
            type: "object",
            required: ["operation"],
            properties: {
              operation: { type: "string", enum: ["create_issue", "create_pr", "create_files_and_pr"] },
              title: { type: "string" },
              body: { type: "string", default: "" },
              pr_title: { type: "string" },
              pr_body: { type: "string", default: "" },
              head: { type: "string" },
              base: { type: "string", default: "main" },
              files: {
                type: "array",
                items: {
                  type: "object",
                  required: ["path", "content"],
                  properties: {
                    path: { type: "string" },
                    content: { type: "string" }
                  }
                }
              }
            }
          }
        }
      }
    },
    error: {
      type: "object",
      required: ["type", "error"],
      properties: {
        type: { type: "string", enum: ["error"] },
        error: { type: "string" },
        details: { type: "object", default: {} }
      }
    }
  }.freeze

  attr_reader :schema_type, :schema_definition

  def initialize(schema_type)
    @schema_type = schema_type.to_sym
    @schema_definition = SCHEMAS[@schema_type]

    raise ArgumentError, "Unknown schema type: #{schema_type}" unless @schema_definition
  end

  # Get schema for a specific type
  def self.for_type(type)
    new(type)
  end

  # Get JSON Schema definition for OpenAI structured outputs
  def to_openai_schema
    @schema_definition.deep_dup
  end

  # Validate and normalize a response against this schema
  def validate_and_normalize(response)
    # Ensure response is a hash with symbol keys
    normalized = normalize_keys(response)

    # Basic type check
    unless normalized[:type] == schema_type.to_s
      raise ValidationError, "Expected type '#{schema_type}', got '#{normalized[:type]}'"
    end

    # Validate required fields
    validate_required_fields(normalized)

    # Apply defaults
    normalized = apply_defaults(normalized)

    # Type-specific validation
    validate_type_specific(normalized)

    normalized
  rescue ValidationError => e
    raise e
  rescue StandardError => e
    raise ValidationError, "Validation failed: #{e.message}"
  end

  # Infer schema type from work_type
  def self.infer_from_work_type(work_type)
    case work_type.to_s
    when /_setup$/, "repo_bootstrap", "rails_setup", "ci_setup", "dependabot_setup",
         "rubocop_setup", "eslint_setup", "git_hooks_setup", "frontend_setup", "readme_setup"
      :github_operations
    when "gtm", "docs"
      :file_writes
    when "product_manager", "orchestrator"
      :work_items
    when "issue"
      :github_operations
    else
      raise ArgumentError, "Cannot infer schema type for work_type: #{work_type}"
    end
  end

  private

  def normalize_keys(data)
    case data
    when Hash
      data.deep_symbolize_keys
    when String
      JSON.parse(data).deep_symbolize_keys
    else
      raise ValidationError, "Response must be a Hash or JSON string"
    end
  end

  def validate_required_fields(normalized)
    required = schema_definition[:required] || []
    missing = required - normalized.keys.map(&:to_s)

    unless missing.empty?
      raise ValidationError, "Missing required fields: #{missing.join(', ')}"
    end
  end

  def apply_defaults(normalized)
    apply_defaults_recursive(normalized, schema_definition[:properties] || {})
  end

  def apply_defaults_recursive(data, properties)
    return data unless data.is_a?(Hash)

    data = data.dup
    properties.each do |key, prop_def|
      key_sym = key.to_sym
      key_str = key.to_s

      # Check both symbol and string keys
      value = data[key_sym] || data[key_str]

      if value.nil? && prop_def[:default]
        data[key_sym] = prop_def[:default]
      elsif value.is_a?(Hash) && prop_def[:properties]
        data[key_sym] = apply_defaults_recursive(value, prop_def[:properties])
      elsif value.is_a?(Array) && prop_def[:items] && prop_def[:items][:properties]
        data[key_sym] = value.map do |item|
          apply_defaults_recursive(item, prop_def[:items][:properties])
        end
      end
    end

    data
  end

  def validate_type_specific(normalized)
    case schema_type
    when :work_items
      validate_work_items(normalized)
    when :file_writes
      validate_file_writes(normalized)
    when :github_operations
      validate_github_operations(normalized)
    end
  end

  def validate_work_items(normalized)
    work_items = normalized[:work_items] || []
    raise ValidationError, "work_items must be a non-empty array" if work_items.empty?

    work_items.each_with_index do |wi, index|
      unless wi[:work_type].present?
        raise ValidationError, "work_items[#{index}]: work_type is required"
      end
      unless wi[:agent_key].present?
        raise ValidationError, "work_items[#{index}]: agent_key is required"
      end
      if wi[:priority] && (wi[:priority] < 1 || wi[:priority] > 10)
        raise ValidationError, "work_items[#{index}]: priority must be between 1 and 10"
      end
    end
  end

  def validate_file_writes(normalized)
    files = normalized[:files] || []
    raise ValidationError, "files must be a non-empty array" if files.empty?

    files.each_with_index do |file, index|
      unless file[:path].present?
        raise ValidationError, "files[#{index}]: path is required"
      end
      unless file[:content].present?
        raise ValidationError, "files[#{index}]: content is required"
      end
    end
  end

  def validate_github_operations(normalized)
    operations = normalized[:operations] || []
    raise ValidationError, "operations must be a non-empty array" if operations.empty?

    operations.each_with_index do |op, index|
      unless op[:operation].present?
        raise ValidationError, "operations[#{index}]: operation is required"
      end
      unless %w[create_issue create_pr create_files_and_pr].include?(op[:operation])
        raise ValidationError, "operations[#{index}]: operation must be 'create_issue', 'create_pr', or 'create_files_and_pr'"
      end

      case op[:operation]
      when "create_issue"
        unless op[:title].present?
          raise ValidationError, "operations[#{index}]: title is required for create_issue"
        end
      when "create_pr"
        unless op[:title].present? || op[:pr_title].present?
          raise ValidationError, "operations[#{index}]: title or pr_title is required for create_pr"
        end
        unless op[:head].present?
          raise ValidationError, "operations[#{index}]: head is required for create_pr"
        end
      when "create_files_and_pr"
        files = op[:files] || []
        unless files.present? && files.is_a?(Array) && !files.empty?
          raise ValidationError, "operations[#{index}]: files array is required for create_files_and_pr"
        end
        files.each_with_index do |file, file_index|
          unless file[:path].present?
            raise ValidationError, "operations[#{index}].files[#{file_index}]: path is required"
          end
          unless file[:content].present?
            raise ValidationError, "operations[#{index}].files[#{file_index}]: content is required"
          end
        end
      end
    end
  end
end

