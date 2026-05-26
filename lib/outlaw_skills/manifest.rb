module OutlawSkills
  module Manifest
    NAME = "outlaw-skills"
    DESCRIPTION = "Personal cross-tool layer of AI coding-agent skills and reviewer personas."
    AUTHOR = {
      "name" => "Andy Cohen",
      "email" => "outlawandy@gmail.com"
    }.freeze
    LICENSE = "MIT"
    KEYWORDS = %w[ai-tooling code-review rails ruby agent-skills].freeze

    def self.claude(version:)
      {
        "name" => NAME,
        "version" => version,
        "description" => DESCRIPTION,
        "author" => AUTHOR,
        "license" => LICENSE,
        "keywords" => KEYWORDS
      }
    end
  end
end
