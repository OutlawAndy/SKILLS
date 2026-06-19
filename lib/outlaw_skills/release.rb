require "json"

module OutlawSkills
  # Raised for any release-pipeline failure. bin/release rescues this and
  # aborts with a clear message, mirroring how bin/build rescues BuildError.
  class ReleaseError < StandardError; end

  # Reads the plugin version from every location that must stay in sync.
  #
  # VERSION is the single source of truth (the build reads it to stamp
  # dist/claude/.claude-plugin/plugin.json), but .claude-plugin/marketplace.json
  # is hand-maintained and carries two more copies of the version. This reader
  # exposes all four so a test can assert they agree (the invariant the
  # release pipeline must preserve).
  class VersionLocations
    def initialize(root:)
      @root = root
    end

    def version_file_path = File.join(@root, "VERSION")
    def marketplace_path  = File.join(@root, ".claude-plugin", "marketplace.json")
    def plugin_json_path  = File.join(@root, "dist", "claude", ".claude-plugin", "plugin.json")

    def version_file
      raise ReleaseError, "VERSION file missing at #{version_file_path}" unless File.file?(version_file_path)
      File.read(version_file_path).strip
    end

    def marketplace_metadata_version
      version = marketplace.dig("metadata", "version")
      raise ReleaseError, "marketplace.json missing metadata.version at #{marketplace_path}" if version.nil?
      version
    end

    def marketplace_plugin_version
      plugins = marketplace["plugins"]
      unless plugins.is_a?(Array) && plugins[0].is_a?(Hash) && plugins[0].key?("version")
        raise ReleaseError, "marketplace.json missing plugins[0].version at #{marketplace_path}"
      end
      plugins[0]["version"]
    end

    def plugin_json_version
      unless File.file?(plugin_json_path)
        raise ReleaseError, "built plugin.json missing at #{plugin_json_path} — run bin/build first"
      end
      version = JSON.parse(File.read(plugin_json_path))["version"]
      raise ReleaseError, "plugin.json missing version at #{plugin_json_path}" if version.nil?
      version
    end

    # All four version strings, keyed by location.
    def all
      {
        version_file: version_file,
        marketplace_metadata: marketplace_metadata_version,
        marketplace_plugin: marketplace_plugin_version,
        plugin_json: plugin_json_version
      }
    end

    # True when every location reports the same version.
    def consistent?
      all.values.uniq.size == 1
    end

    private

    def marketplace
      raise ReleaseError, "marketplace.json missing at #{marketplace_path}" unless File.file?(marketplace_path)
      JSON.parse(File.read(marketplace_path))
    rescue JSON::ParserError => e
      raise ReleaseError, "marketplace.json malformed at #{marketplace_path}: #{e.message}"
    end
  end
end
