module OutlawSkills
  module Manifest
    NAME = "outlaw-skills"
    DESCRIPTION = "Personal cross-tool layer of AI coding-agent skills and reviewer personas."
    HOMEPAGE = "https://github.com/OutlawAndy/SKILLS"
    REPOSITORY = "https://github.com/OutlawAndy/SKILLS"
    AUTHOR = {
      "name" => "Andy Cohen",
      "email" => "outlawandy@gmail.com"
    }.freeze
    LICENSE = "MIT"
    KEYWORDS = %w[ai-tooling code-review rails ruby agent-skills].freeze

    # The single plugin manifest. Both Claude Code and Copilot CLI read it from
    # .claude-plugin/plugin.json and ignore fields they do not recognize.
    def self.build(version:)
      {
        "name" => NAME,
        "version" => version,
        "description" => DESCRIPTION,
        "homepage" => HOMEPAGE,
        "repository" => REPOSITORY,
        "author" => AUTHOR,
        "license" => LICENSE,
        "keywords" => KEYWORDS
      }
    end
  end
end
