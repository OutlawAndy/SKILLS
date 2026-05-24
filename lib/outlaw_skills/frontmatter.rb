require "yaml"

module OutlawSkills
  module Frontmatter
    FRONTMATTER_RE = /\A---\s*\n(.*?\n)---\s*\n(.*)\z/m

    # Returns [frontmatter_hash, body_string]. Raises with a clear message
    # when frontmatter is present but malformed.
    def self.parse(content, source_path: "<unknown>")
      match = FRONTMATTER_RE.match(content)
      return [{}, content] unless match

      yaml_text, body = match[1], match[2]
      begin
        fm = YAML.safe_load(yaml_text, permitted_classes: [Symbol], aliases: false) || {}
      rescue Psych::SyntaxError => e
        raise BuildError, "malformed YAML frontmatter in #{source_path}: #{e.message}"
      end
      raise BuildError, "frontmatter in #{source_path} must be a YAML mapping, got #{fm.class}" unless fm.is_a?(Hash)

      [fm, body]
    end
  end

  class BuildError < StandardError; end
end
