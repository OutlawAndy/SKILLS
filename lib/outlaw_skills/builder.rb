require_relative "frontmatter"
require_relative "manifest"
require_relative "targets/plugin"

module OutlawSkills
  # CLI entry point used by bin/build.
  #
  # There is a single distribution: dist/plugin/. Both Claude Code and Copilot
  # CLI read the same plugin layout natively (`.claude-plugin/plugin.json`,
  # `skills/<name>/SKILL.md`, `agents/*.agent.md`, `hooks/hooks.json`), so one
  # tree serves both tools and no per-target conversion is performed.
  module CLI
    def self.run(argv, root: default_root)
      unless argv.empty? || argv == ["plugin"]
        abort "usage: bin/build  (builds the single dist/plugin/ tree)"
      end

      Builder.new(root: root).build
      $stderr.puts "built: dist/plugin"
    rescue BuildError => e
      abort "build error: #{e.message}"
    end

    def self.default_root
      File.expand_path("../..", __dir__)
    end
  end

  class Builder
    attr_reader :root

    def initialize(root:)
      @root = root
      raise BuildError, "src/ directory missing at #{src_root}" unless File.directory?(src_root)
      raise BuildError, "VERSION file missing at #{version_file}" unless File.file?(version_file)
    end

    def src_root  = File.join(@root, "src")
    def dist_root = File.join(@root, "dist")
    def hooks_src = File.join(src_root, "hooks")
    def version_file = File.join(@root, "VERSION")
    def version = @version ||= File.read(version_file).strip

    def build
      Targets::Plugin.new(self).build
    end

    # All discovered skills. Validates frontmatter eagerly so malformed
    # content fails the build with a clear file-named error regardless of
    # where the failure would otherwise surface.
    def skills
      @skills ||= Dir.glob(File.join(src_root, "skills", "*")).select { |p| File.directory?(p) }.sort.map do |path|
        Skill.new(path)
      end
    end

    def agents
      @agents ||= Dir.glob(File.join(src_root, "agents", "*.agent.md")).sort.map { |p| Agent.new(p) }
    end
  end

  class Skill
    attr_reader :path

    def initialize(path)
      @path = path
      @name = File.basename(path)
      validate!
    end

    def name = @name
    def skill_md_path = File.join(@path, "SKILL.md")

    def frontmatter
      @frontmatter ||= Frontmatter.parse(File.read(skill_md_path, encoding: "UTF-8"), source_path: skill_md_path).first
    end

    private

    def validate!
      raise BuildError, "skill #{@name} missing SKILL.md at #{skill_md_path}" unless File.file?(skill_md_path)
      frontmatter # trigger parse; raises BuildError on malformed YAML
    end
  end

  class Agent
    attr_reader :path

    def initialize(path)
      @path = path
      @name = File.basename(path, ".agent.md")
      validate!
    end

    def name = @name

    def frontmatter
      @frontmatter ||= Frontmatter.parse(File.read(@path, encoding: "UTF-8"), source_path: @path).first
    end

    private

    def validate!
      frontmatter
    end
  end
end
