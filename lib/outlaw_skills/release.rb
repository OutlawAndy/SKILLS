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
  # dist/plugin/.claude-plugin/plugin.json). Two hand-maintained marketplace
  # manifests each carry two more copies of the version: .claude-plugin/
  # marketplace.json (Claude) and .github/plugin/marketplace.json (Copilot).
  # This reader exposes every copy so a test can assert they all agree (the
  # invariant the release pipeline must preserve).
  class VersionLocations
    # Marketplace manifests, keyed for messages and iteration. Both point their
    # plugin `source` at the single dist/plugin/ tree.
    MARKETPLACES = {
      claude:  [".claude-plugin", "marketplace.json"],
      copilot: [".github", "plugin", "marketplace.json"]
    }.freeze

    def initialize(root:)
      @root = root
    end

    def version_file_path = File.join(@root, "VERSION")
    def plugin_json_path  = File.join(@root, "dist", "plugin", ".claude-plugin", "plugin.json")

    # Absolute paths to the two marketplace manifests, keyed as in MARKETPLACES.
    def marketplace_paths
      MARKETPLACES.transform_values { |parts| File.join(@root, *parts) }
    end

    def version_file
      raise ReleaseError, "VERSION file missing at #{version_file_path}" unless File.file?(version_file_path)
      File.read(version_file_path).strip
    end

    def marketplace_metadata_version(path)
      version = read_marketplace(path).dig("metadata", "version")
      raise ReleaseError, "marketplace.json missing metadata.version at #{path}" if version.nil?
      version
    end

    def marketplace_plugin_version(path)
      plugins = read_marketplace(path)["plugins"]
      unless plugins.is_a?(Array) && plugins[0].is_a?(Hash) && plugins[0].key?("version")
        raise ReleaseError, "marketplace.json missing plugins[0].version at #{path}"
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

    # Every version string, keyed by location. Two entries per marketplace
    # (metadata + plugin) plus VERSION and the built plugin.json.
    def all
      result = { version_file: version_file, plugin_json: plugin_json_version }
      marketplace_paths.each do |key, path|
        result[:"#{key}_marketplace_metadata"] = marketplace_metadata_version(path)
        result[:"#{key}_marketplace_plugin"]   = marketplace_plugin_version(path)
      end
      result
    end

    # True when every location reports the same version.
    def consistent?
      all.values.uniq.size == 1
    end

    private

    def read_marketplace(path)
      raise ReleaseError, "marketplace.json missing at #{path}" unless File.file?(path)
      JSON.parse(File.read(path))
    rescue JSON::ParserError => e
      raise ReleaseError, "marketplace.json malformed at #{path}: #{e.message}"
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

    # Removes untracked files/dirs under the given paths. Used in rollback so a
    # failed release that rebuilt dist (possibly adding new files) leaves no
    # orphaned artifacts behind — `git checkout --` only restores tracked files.
    def clean_untracked(*paths)
      run!("git", "-C", @root, "clean", "-fd", "--", *paths)
    end

    private

    def capture(*args)
      output = IO.popen(args, &:read)
      raise ReleaseError, "command failed: #{args.join(' ')}" unless $?.success?
      output.to_s
    end

    def run!(*args)
      raise ReleaseError, "command failed: #{args.join(' ')}" unless system(*args)
    end
  end

  # Thin GitHub-CLI wrapper, injectable for tests. Degrades gracefully: the
  # release completes locally even when gh is missing or unauthenticated.
  class Gh
    def available?
      on_path? && authenticated?
    end

    # Returns true on success, false on failure. The caller degrades gracefully
    # on false (the tag is already pushed by then) rather than aborting, and gh's
    # own stderr is inherited so the operator sees why it failed.
    def release_create(tag)
      system("gh", "release", "create", tag, "--generate-notes")
    end

    # The exact command a developer runs by hand when gh wasn't usable.
    def manual_command(tag)
      "gh release create #{tag} --generate-notes"
    end

    private

    def on_path?
      system("command -v gh > /dev/null 2>&1")
    end

    def authenticated?
      system("gh", "auth", "status", out: File::NULL, err: File::NULL)
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
    BUMP_PATHS = ["VERSION", ".claude-plugin/marketplace.json", ".github/plugin/marketplace.json", "dist"].freeze

    def initialize(root:, level: "patch", dry_run: false, gh_release: true,
                   override_branch: false, release_branch: "main", out: $stdout,
                   git: nil, gh: nil, test_gate: nil, build: nil)
      @root = root
      @level = level
      @dry_run = dry_run
      @gh_release = gh_release
      @override_branch = override_branch
      @release_branch = release_branch
      @out = out
      @locations = VersionLocations.new(root: root)
      @git = git || Git.new(root: root)
      @gh = gh || Gh.new
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
      ensure_release_branch!
      ensure_tag_available!(next_version)

      apply_version(next_version)
      run_test_gate!(next_version)
      commit_and_tag(next_version)
      publish(next_version)
      print_refresh(next_version)
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

    def ensure_release_branch!
      return if @override_branch
      branch = @git.current_branch
      return if branch == @release_branch
      raise ReleaseError,
        "on branch #{branch.inspect}, not the release branch #{@release_branch.inspect} — " \
        "switch to #{@release_branch} or pass --override"
    end

    def ensure_tag_available!(version)
      tag = "v#{version}"
      return unless @git.tag_exists?(tag)
      raise ReleaseError, "tag #{tag} already exists — v#{version} appears already released"
    end

    def commit_and_tag(version)
      tag = "v#{version}"
      @git.add(*BUMP_PATHS)
      @git.commit("chore(release): v#{version}")
      @git.tag(tag, "Release v#{version}")
    end

    def publish(version)
      tag = "v#{version}"
      @git.push(@git.current_branch, tag)

      unless @gh_release
        @out.puts "Skipped GitHub release (--no-gh-release). Tag #{tag} pushed."
        return
      end

      if @gh.available?
        if @gh.release_create(tag)
          @out.puts "Created GitHub release #{tag}."
        else
          @out.puts "gh release create failed — tag #{tag} is pushed; finish the release manually:"
          @out.puts "  #{@gh.manual_command(tag)}"
        end
      else
        @out.puts "gh unavailable or unauthenticated — tag #{tag} is pushed; create the release manually:"
        @out.puts "  #{@gh.manual_command(tag)}"
      end
    end

    def print_refresh(version)
      @out.puts ""
      @out.puts "Released v#{version}. To refresh Claude Code's cached copy:"
      @out.puts "  /plugin update outlaw-skills@outlaw-skills"
      @out.puts "or relaunch your Claude Code session."
    end

    def apply_version(next_version)
      File.write(@locations.version_file_path, "#{next_version}\n")
      @locations.marketplace_paths.each_value { |path| MarketplaceSync.write(path, next_version) }
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
      @git.clean_untracked("dist")
    end

    def report_dry_run(current, next_version)
      tag = "v#{next_version}"
      branch = @git.current_branch
      branch_note = @override_branch ? "#{branch} (override on)" : "#{branch} (release branch: #{@release_branch})"
      release_note = @gh_release ? "#{@gh.manual_command(tag)}" : "skip GitHub release"
      @out.puts "[dry-run] would bump #{current} -> #{next_version}"
      @out.puts "[dry-run] would write: #{BUMP_PATHS.join(', ')} (after rebuild)"
      @out.puts "[dry-run] tracked tree is #{@git.clean_tracked? ? 'clean' : 'DIRTY — a real run would abort until committed/stashed'}"
      @out.puts "[dry-run] branch: #{branch_note}"
      @out.puts "[dry-run] would commit + tag #{tag} + push, then: #{release_note}"
      @out.puts "[dry-run] no files, git, or GitHub changes made"
    end

    def default_build
      Builder.new(root: @root).build
    end
  end

  # CLI entry used by bin/release.
  module ReleaseCLI
    USAGE = <<~TEXT.freeze
      Usage: bin/release [major|minor|patch] [--dry-run] [--no-gh-release] [--override]

        major|minor|patch   semver level to bump (default: patch)
        --dry-run           report the planned release without changing anything
        --no-gh-release     commit, tag, and push, but skip creating the GitHub release
        --override          allow releasing from a branch other than main
    TEXT

    def self.run(argv, root: default_root, out: $stdout)
      level = "patch"
      dry_run = false
      gh_release = true
      override_branch = false

      argv.each do |arg|
        case arg
        when "major", "minor", "patch" then level = arg
        when "--dry-run" then dry_run = true
        when "--no-gh-release" then gh_release = false
        when "--override" then override_branch = true
        when "-h", "--help" then out.puts(USAGE); return
        else abort "unknown argument: #{arg.inspect}\n#{USAGE}"
        end
      end

      Releaser.new(root: root, level: level, dry_run: dry_run, gh_release: gh_release,
                   override_branch: override_branch, out: out).run
    rescue ReleaseError => e
      abort "release error: #{e.message}"
    end

    def self.default_root = CLI.default_root
  end
end
