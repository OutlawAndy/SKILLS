require "json"
require "rbconfig"
require_relative "builder"

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

  # Pure semver bump. Rejects non-semver input and unknown levels so the
  # release aborts before mutating anything.
  module SemVer
    LEVELS = %w[major minor patch].freeze

    module_function

    def bump(version, level)
      unless version =~ /\A(\d+)\.(\d+)\.(\d+)\z/
        raise ReleaseError, "VERSION #{version.inspect} is not semver (expected MAJOR.MINOR.PATCH)"
      end
      major, minor, patch = Regexp.last_match(1).to_i, Regexp.last_match(2).to_i, Regexp.last_match(3).to_i
      case level
      when "major" then "#{major + 1}.0.0"
      when "minor" then "#{major}.#{minor + 1}.0"
      when "patch" then "#{major}.#{minor}.#{patch + 1}"
      else raise ReleaseError, "unknown bump level #{level.inspect} (expected: #{LEVELS.join(', ')})"
      end
    end
  end

  # Writes the new version into both marketplace.json version fields while
  # preserving the file's exact formatting (key order + 2-space pretty-print),
  # so the only diff is the version lines.
  module MarketplaceSync
    module_function

    def write(path, version)
      data = JSON.parse(File.read(path))
      data.fetch("metadata")["version"] = version
      data.fetch("plugins")[0]["version"] = version
      File.write(path, JSON.pretty_generate(data) + "\n")
    end
  end

  # Thin git wrapper, injectable so the release orchestration can be tested
  # without a real repository.
  class Git
    def initialize(root:)
      @root = root
    end

    # Tracked-only cleanliness: untracked scratch (e.g. ref/) does not block.
    def clean_tracked?
      capture("git", "-C", @root, "status", "--porcelain", "--untracked-files=no").strip.empty?
    end

    def current_branch
      capture("git", "-C", @root, "rev-parse", "--abbrev-ref", "HEAD").strip
    end

    def tag_exists?(tag)
      system("git", "-C", @root, "rev-parse", "-q", "--verify", "refs/tags/#{tag}",
             out: File::NULL, err: File::NULL)
    end

    def add(*paths)
      run!("git", "-C", @root, "add", *paths)
    end

    def commit(message)
      run!("git", "-C", @root, "commit", "-m", message)
    end

    def tag(name, message)
      run!("git", "-C", @root, "tag", "-a", name, "-m", message)
    end

    def push(*refs)
      run!("git", "-C", @root, "push", "origin", *refs)
    end

    # Discards working-tree changes to the bump's tracked paths (rollback).
    def restore(*paths)
      run!("git", "-C", @root, "checkout", "--", *paths)
    end

    private

    def capture(*args)
      IO.popen(args, &:read).to_s
    end

    def run!(*args)
      raise ReleaseError, "command failed: #{args.join(' ')}" unless system(*args)
    end
  end

  # Runs the project test suite the only way it collects tests: with test/ as
  # the working directory (test_helper.rb globs ./*_test.rb relatively). Treats
  # a zero-tests-collected result as failure so the gate cannot false-green.
  class TestGate
    attr_reader :last_output

    def initialize(root:)
      @root = root
    end

    def pass?
      status = nil
      Dir.chdir(File.join(@root, "test")) do
        @last_output = IO.popen([RbConfig.ruby, "test_helper.rb", err: %i[child out]], &:read)
        status = $?
      end
      return false unless status.success?
      return false if @last_output =~ /\b0 runs\b/ # zero tests collected == failure
      true
    end
  end

  # Orchestrates a semver release: clean-tree check, bump, marketplace sync,
  # rebuild, test gate (with rollback on failure). Publishing (branch guard,
  # commit, tag, push, GitHub release) is layered on in U3.
  class Releaser
    BUMP_PATHS = ["VERSION", ".claude-plugin/marketplace.json", "dist"].freeze

    def initialize(root:, level: "patch", dry_run: false, out: $stdout,
                   git: nil, test_gate: nil, build: nil)
      @root = root
      @level = level
      @dry_run = dry_run
      @out = out
      @locations = VersionLocations.new(root: root)
      @git = git || Git.new(root: root)
      @test_gate = test_gate || TestGate.new(root: root)
      @build = build || method(:default_build)
    end

    def run
      validate_level!

      current = @locations.version_file
      next_version = SemVer.bump(current, @level)

      if @dry_run
        report_dry_run(current, next_version)
        return next_version
      end

      ensure_clean_tree!
      apply_version(next_version)
      run_test_gate!(next_version)
      @out.puts "Prepared and verified v#{next_version} (VERSION, marketplace.json synced, dist rebuilt)."
      next_version
    end

    private

    def validate_level!
      return if SemVer::LEVELS.include?(@level)
      raise ReleaseError, "unknown bump level #{@level.inspect} (expected: #{SemVer::LEVELS.join(', ')})"
    end

    def ensure_clean_tree!
      return if @git.clean_tracked?
      raise ReleaseError,
        "working tree has uncommitted tracked changes — commit or stash them first " \
        "(untracked files like ref/ do not block)"
    end

    def apply_version(next_version)
      File.write(@locations.version_file_path, "#{next_version}\n")
      MarketplaceSync.write(@locations.marketplace_path, next_version)
      @build.call
    end

    def run_test_gate!(next_version)
      return if @test_gate.pass?
      rollback!
      raise ReleaseError,
        "test gate failed for v#{next_version} — rolled back the bump. Test output:\n#{@test_gate.last_output}"
    end

    def rollback!
      @git.restore(*BUMP_PATHS)
    end

    def report_dry_run(current, next_version)
      @out.puts "[dry-run] would bump #{current} -> #{next_version}"
      @out.puts "[dry-run] would write: #{BUMP_PATHS.join(', ')} (after rebuild)"
      @out.puts "[dry-run] tracked tree is #{@git.clean_tracked? ? 'clean' : 'DIRTY — a real run would abort until committed/stashed'}"
      @out.puts "[dry-run] no files, git, or GitHub changes made"
    end

    def default_build
      builder = Builder.new(root: @root)
      builder.build_target("claude")
      builder.build_target("copilot")
    end
  end

  # CLI entry used by bin/release.
  module ReleaseCLI
    USAGE = <<~TEXT.freeze
      Usage: bin/release [major|minor|patch] [--dry-run]

        major|minor|patch   semver level to bump (default: patch)
        --dry-run           report the planned bump without changing anything
    TEXT

    def self.run(argv, root: default_root, out: $stdout)
      level = "patch"
      dry_run = false

      argv.each do |arg|
        case arg
        when "major", "minor", "patch" then level = arg
        when "--dry-run" then dry_run = true
        when "-h", "--help" then out.puts(USAGE); return
        else abort "unknown argument: #{arg.inspect}\n#{USAGE}"
        end
      end

      Releaser.new(root: root, level: level, dry_run: dry_run, out: out).run
    rescue ReleaseError => e
      abort "release error: #{e.message}"
    end

    def self.default_root = File.expand_path("../..", __dir__)
  end
end
