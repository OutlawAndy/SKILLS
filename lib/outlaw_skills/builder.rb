require_relative "frontmatter"
require_relative "manifest"
require_relative "targets/claude"

module OutlawSkills
  # CLI entry point used by bin/build.
  module CLI
    KNOWN_TARGETS = %w[claude copilot all].freeze

    def self.run(argv, root: default_root)
      target = argv.first || "all"
      unless KNOWN_TARGETS.include?(target)
        abort "unknown target: #{target.inspect} (known: #{KNOWN_TARGETS.join(', ')})"
      end

      builder = Builder.new(root: root)
      targets = case target
                when "all"     then ["claude"] # copilot added in U6
                when "claude"  then ["claude"]
                when "copilot" then abort("copilot target not yet implemented (plan unit U6)")
                end

      targets.each { |t| builder.build_target(t) }
      $stderr.puts "built: #{targets.join(', ')}"
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

    def build_target(name)
      case name
      when "claude" then Targets::Claude.new(self).build
      else raise BuildError, "no target implementation for #{name}"
      end
    end

    # All discovered skills. Validates frontmatter eagerly so malformed
    # content fails the build with a clear file-named error (R8) regardless
    # of whether `targets:` filtering applies in the current target.
    def skills
      @skills ||= Dir.glob(File.join(src_root, "skills", "*")).select { |p| File.directory?(p) }.sort.map do |path|
        Skill.new(path)
      end
    end

    def agents
      @agents ||= Dir.glob(File.join(src_root, "agents", "*.agent.md")).sort.map { |p| Agent.new(p) }
    end

    # Per-target filtering hooks. U4 default: include everything (no `targets:`
    # filter yet — that arrives in U5). Targets call these so U5 can plug in
    # without touching per-target code.
    def skills_for(_target_name)  = skills
    def agents_for(_target_name)  = agents
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
