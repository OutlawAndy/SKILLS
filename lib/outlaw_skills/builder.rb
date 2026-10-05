require_relative "frontmatter"
require_relative "manifest"
require_relative "targets/plugin"

module OutlawSkills
  # CLI entry point used by bin/build.
  #
  # The main distribution is dist/plugin/, built from src/. Each src/plugins/<name>/
  # is a smaller standalone plugin built to dist/<name>/ for people who want just
  # that piece. Both Claude Code and Copilot CLI read the same plugin layout
  # natively (`.claude-plugin/plugin.json`, `skills/<name>/SKILL.md`,
  # `agents/*.agent.md`, `hooks/hooks.json`), so no per-target conversion is performed.
  module CLI
    def self.run(argv, root: default_root)
      unless argv.empty? || argv == ["plugin"]
        abort "usage: bin/build  (builds every plugin tree under dist/)"
      end

      builder = Builder.new(root: root)
      builder.build
      builder.plugins.each { |plugin| $stderr.puts "built: #{plugin.dist_dir.delete_prefix("#{root}/")}" }
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
    def version_file = File.join(@root, "VERSION")
    def version = @version ||= File.read(version_file).strip

    def build
      plugins.each { |plugin| Targets::Plugin.new(self, plugin).build }
    end

    def plugins
      @plugins ||= [
        PluginSource.new(name: Manifest::NAME, src_dir: src_root,
                         dist_dir: File.join(dist_root, "plugin"), root_files: %w[AGENTS.md LICENSE]),
        *Dir.glob(File.join(src_root, "plugins", "*")).select { |p| File.directory?(p) }.sort.map do |path|
          name = File.basename(path)
          PluginSource.new(name: name, src_dir: path, dist_dir: File.join(dist_root, name), root_files: %w[LICENSE])
        end
      ]
    end

    def skills = plugins.flat_map(&:skills)
  end

  # One plugin's canonical source: skills/, agents/, and hooks/ under src_dir.
  class PluginSource
    attr_reader :name, :src_dir, :dist_dir, :root_files

    def initialize(name:, src_dir:, dist_dir:, root_files:)
      @name = name
      @src_dir = src_dir
      @dist_dir = dist_dir
      @root_files = root_files
    end

    def hooks_src = File.join(src_dir, "hooks")

    # Validates frontmatter eagerly so malformed content fails the build with
    # a clear file-named error regardless of where the failure would otherwise
    # surface.
    def skills
      @skills ||= Dir.glob(File.join(src_dir, "skills", "*")).select { |p| File.directory?(p) }.sort.map do |path|
        Skill.new(path)
      end
    end

    def agents
      @agents ||= Dir.glob(File.join(src_dir, "agents", "*.agent.md")).sort.map { |p| Agent.new(p) }
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
