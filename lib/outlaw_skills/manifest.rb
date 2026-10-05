module OutlawSkills
  module Manifest
    NAME = "outlaw-skills"
    HOMEPAGE = "https://github.com/OutlawAndy/SKILLS"
    REPOSITORY = "https://github.com/OutlawAndy/SKILLS"
    AUTHOR = {
      "name" => "Andy Cohen",
      "email" => "outlawandy@gmail.com"
    }.freeze
    LICENSE = "MIT"

    PLUGINS = {
      NAME => {
        "description" => "Personal cross-tool layer of AI coding-agent skills and reviewer personas.",
        "keywords" => %w[ai-tooling code-review rails ruby agent-skills]
      },
      "driving" => {
        "description" => "Hands-free mode: reads each response aloud and takes decisions one at a time.",
        "keywords" => %w[voice hands-free accessibility]
      }
    }.freeze

    # A plugin manifest. Both Claude Code and Copilot CLI read it from
    # .claude-plugin/plugin.json and ignore fields they do not recognize.
    def self.build(version:, name: NAME)
      details = PLUGINS.fetch(name) { raise BuildError, "no manifest details for plugin #{name}" }
      {
        "name" => name,
        "version" => version,
        "description" => details["description"],
        "homepage" => HOMEPAGE,
        "repository" => REPOSITORY,
        "author" => AUTHOR,
        "license" => LICENSE,
        "keywords" => details["keywords"]
      }
    end
  end
end
