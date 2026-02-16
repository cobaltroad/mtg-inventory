require "yaml"
require "fileutils"

class CardListWriter
  # Custom error class
  class WriteError < StandardError; end

  # Default output directory
  DEFAULT_OUTPUT_DIR = Rails.root.join("config", "card_lists")

  class << self
    # ---------------------------------------------------------------------------
    # Write a card list to a YAML file
    #
    # Arguments:
    #   list_name (String) - Name of the list (will be used as filename without extension)
    #   cards (Array<String>) - Array of card names
    #   source_url (String) - URL of the data source
    #
    # Returns: Pathname - Path to the written file
    # Raises: WriteError on validation or file system errors
    # ---------------------------------------------------------------------------
    def write(list_name, cards, source_url)
      validate_list_name!(list_name)
      ensure_output_directory!

      file_path = output_directory.join("#{list_name}.yml")

      # Prepare YAML data structure
      yaml_data = build_yaml_structure(cards, source_url)

      # Write to file with atomic operation (write to temp, then move)
      write_yaml_file(file_path, yaml_data)

      file_path
    rescue Errno::EACCES => e
      raise WriteError, "Permission denied writing to #{file_path}: #{e.message}"
    rescue Errno::EIO, Errno::ENOSPC => e
      raise WriteError, "File system error writing to #{file_path}: #{e.message}"
    rescue StandardError => e
      # Re-raise WriteError as-is, wrap other errors
      raise WriteError, "Failed to write card list '#{list_name}': #{e.message}" unless e.is_a?(WriteError)
      raise
    end

    # ---------------------------------------------------------------------------
    # Get the output directory (config/card_lists by default)
    # ---------------------------------------------------------------------------
    def output_directory
      @output_directory || DEFAULT_OUTPUT_DIR
    end

    private

    # ---------------------------------------------------------------------------
    # Validate list_name to prevent directory traversal and empty names
    # ---------------------------------------------------------------------------
    def validate_list_name!(list_name)
      if list_name.blank?
        raise WriteError, "List name cannot be blank"
      end

      # Check for directory traversal attempts
      if list_name.include?("/") || list_name.include?("\\") || list_name.include?("..")
        raise WriteError, "Invalid list name: cannot contain path separators or directory traversal"
      end
    end

    # ---------------------------------------------------------------------------
    # Ensure output directory exists
    # ---------------------------------------------------------------------------
    def ensure_output_directory!
      output_directory.mkpath unless output_directory.exist?
    rescue Errno::EACCES => e
      raise WriteError, "Permission denied creating directory #{output_directory}: #{e.message}"
    end

    # ---------------------------------------------------------------------------
    # Build YAML data structure with proper format
    # ---------------------------------------------------------------------------
    def build_yaml_structure(cards, source_url)
      # Normalize cards: remove duplicates, sort alphabetically
      normalized_cards = cards.compact.uniq.sort

      {
        "cards" => normalized_cards,
        "last_updated" => Date.today.iso8601,
        "source" => source_url
      }
    end

    # ---------------------------------------------------------------------------
    # Write YAML file with proper formatting
    # ---------------------------------------------------------------------------
    def write_yaml_file(file_path, yaml_data)
      # Generate YAML string with proper formatting
      # YAML.dump creates compact format, but we want indented lists
      yaml_string = format_yaml_with_indentation(yaml_data)

      # Write to file
      # Use atomic write pattern: write to temp file, then move
      begin
        temp_file = Tempfile.new([ "card_list", ".yml" ], output_directory)
      rescue Errno::EACCES => e
        raise WriteError, "Permission denied writing to #{file_path}: #{e.message}"
      end

      begin
        temp_file.write(yaml_string)
        temp_file.close
        FileUtils.mv(temp_file.path, file_path)
      rescue StandardError => e
        temp_file.close
        temp_file.unlink
        raise e
      end
    end

    # ---------------------------------------------------------------------------
    # Format YAML with proper indentation for readability
    # ---------------------------------------------------------------------------
    def format_yaml_with_indentation(yaml_data)
      # Build YAML manually for better formatting control
      lines = [ "---" ]

      # Handle cards array
      if yaml_data["cards"].empty?
        lines << "cards: []"
      else
        lines << "cards:"
        yaml_data["cards"].each do |card|
          # Quote card names and indent with 2 spaces
          lines << "  - \"#{card}\""
        end
      end

      lines << "last_updated: '#{yaml_data["last_updated"]}'"
      lines << "source: #{yaml_data["source"]}"

      lines.join("\n") + "\n"
    end
  end
end
