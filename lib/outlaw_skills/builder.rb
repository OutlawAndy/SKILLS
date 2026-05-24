require_relative "frontmatter"
require_relative "manifest"
require_relative "targets/claude"

module OutlawSkills
  # Known build targets — recognized values for the `targets:` frontmatter
  # field and the bin/build CLI argument.
  TARGETS = %w[claude copilot].freeze

  # CLI entry point used by bin/build.
  module CLI
    VALID_ARGS = (TARGETS + ["all"]).freeze

    def self.run(argv, root: default_root)
      arg = argv.first || "all"
      unless VALID_ARGS.include?(arg)
        abort "unknown target: #{arg.inspect} (known: #{VALID_ARGS.join(', ')})"
      end

      builder = Builder.new(root: root)
      targets = case arg
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

  # Resolves a `targets:` frontmatter field into a list of build-target names.
  # Shared between Skill and Agent so the validation rules live in one place.
  module Targetable
    def targets
      @targets ||= resolve_targets
    end

    def targets?(target_name)
      targets.include?(target_name)
    end

    private

    def resolve_targets
      raw = frontmatter["targets"]
      return TARGETS if raw.nil?

      raise BuildError, "#{targetable_source}: `targets:` must be an array, got #{raw.class}" unless raw.is_a?(Array)
      raise BuildError, "#{targetable_source}: `targets:` cannot be empty" if raw.empty?

      unknown = raw - TARGETS
      warn "warning: #{targetable_source}: ignoring unknown target(s): #{unknown.inspect}" if unknown.any?
      recognized = raw & TARGETS
      if recognized.empty?
        raise BuildError,
          "#{targetable_source}: `targets:` contains no known targets " \
            "(got #{raw.inspect}, known: #{TARGETS.inspect})"
      end
      recognized
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

    # Per-target filtering. Items with no `targets:` field default to all
    # known targets. Items with an explicit list are included only when the
    # current target appears in that list.
    def skills_for(target_name)
      skills.select { |s| s.targets?(target_name) }
    end

    def agents_for(target_name)
      agents.select { |a| a.targets?(target_name) }
    end
  end

  class Skill
    include Targetable

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

    def targetable_source = skill_md_path

    def validate!
      raise BuildError, "skill #{@name} missing SKILL.md at #{skill_md_path}" unless File.file?(skill_md_path)
      frontmatter # trigger parse; raises BuildError on malformed YAML
      targets     # trigger targets resolution; raises BuildError on invalid `targets:`
    end
  end

  class Agent
    include Targetable

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

    def targetable_source = @path

    def validate!
      frontmatter
      targets
    end
  end
end
