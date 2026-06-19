require_relative "test_helper"
require "outlaw_skills/release"
require "json"
require "fileutils"
require "tmpdir"
require "stringio"

# --- shared fixtures and fakes ------------------------------------------------

module ReleaseFixtures
  def write_repo_fixture(dir, version)
    File.write(File.join(dir, "VERSION"), "#{version}\n")

    plugin_dir = File.join(dir, ".claude-plugin")
    FileUtils.mkdir_p(plugin_dir)
    marketplace = {
      "name" => "outlaw-skills",
      "metadata" => { "description" => "x", "version" => version },
      "plugins" => [{ "name" => "outlaw-skills", "version" => version, "source" => "./dist/claude" }]
    }
    File.write(File.join(plugin_dir, "marketplace.json"), JSON.pretty_generate(marketplace) + "\n")

    dist_plugin_dir = File.join(dir, "dist", "claude", ".claude-plugin")
    FileUtils.mkdir_p(dist_plugin_dir)
    File.write(File.join(dist_plugin_dir, "plugin.json"),
               JSON.pretty_generate({ "name" => "outlaw-skills", "version" => version }) + "\n")
  end

  # Re-stamps dist plugin.json from VERSION, standing in for the real build so
  # the invariant holds after apply_version without needing a full src/ tree.
  def stamping_build(dir)
    lambda do
      version = File.read(File.join(dir, "VERSION")).strip
      path = File.join(dir, "dist", "claude", ".claude-plugin", "plugin.json")
      data = JSON.parse(File.read(path))
      data["version"] = version
      File.write(path, JSON.pretty_generate(data) + "\n")
    end
  end
end

class FakeGit
  attr_reader :calls

  def initialize(clean: true, branch: "main", tag_exists: false)
    @clean = clean
    @branch = branch
    @tag_exists = tag_exists
    @calls = []
  end

  def clean_tracked? = @clean
  def current_branch = @branch
  def tag_exists?(_tag) = @tag_exists
  def add(*paths) = @calls << [:add, *paths]
  def commit(message) = @calls << [:commit, message]
  def tag(name, message) = @calls << [:tag, name, message]
  def push(*refs) = @calls << [:push, *refs]
  def restore(*paths) = @calls << [:restore, *paths]
end

class FakeTestGate
  attr_reader :last_output

  def initialize(pass:, output: "")
    @pass = pass
    @last_output = output
  end

  def pass? = @pass
end

# --- U1: version locations / invariant ----------------------------------------

class ReleaseVersionLocationsTest < Minitest::Test
  include ReleaseFixtures

  # The load-bearing invariant (R4): in the real repo, VERSION, both
  # marketplace.json version fields, and the built plugin.json all agree.
  def test_real_repo_versions_are_consistent
    locations = OutlawSkills::VersionLocations.new(root: ROOT)
    assert locations.consistent?, "version drift across locations: #{locations.all.inspect}"
  end

  def test_reads_each_location
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "1.2.3")
      locations = OutlawSkills::VersionLocations.new(root: dir)
      assert_equal "1.2.3", locations.version_file
      assert_equal "1.2.3", locations.marketplace_metadata_version
      assert_equal "1.2.3", locations.marketplace_plugin_version
      assert_equal "1.2.3", locations.plugin_json_version
      assert locations.consistent?
    end
  end

  def test_detects_drift
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "1.2.3")
      mp = File.join(dir, ".claude-plugin", "marketplace.json")
      data = JSON.parse(File.read(mp))
      data["plugins"][0]["version"] = "0.9.9"
      File.write(mp, JSON.pretty_generate(data) + "\n")
      refute OutlawSkills::VersionLocations.new(root: dir).consistent?
    end
  end

  def test_malformed_marketplace_raises_clear_error
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "1.0.0")
      File.write(File.join(dir, ".claude-plugin", "marketplace.json"), "{ not json")
      error = assert_raises(OutlawSkills::ReleaseError) do
        OutlawSkills::VersionLocations.new(root: dir).marketplace_metadata_version
      end
      assert_match(/malformed/, error.message)
    end
  end

  def test_missing_plugin_json_directs_to_build
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "1.0.0")
      FileUtils.rm_rf(File.join(dir, "dist"))
      error = assert_raises(OutlawSkills::ReleaseError) do
        OutlawSkills::VersionLocations.new(root: dir).plugin_json_version
      end
      assert_match(%r{bin/build}, error.message)
    end
  end
end

# --- U2: semver, marketplace sync, test gate, releaser core -------------------

class ReleaseSemVerTest < Minitest::Test
  def test_bump_levels
    assert_equal "0.1.1", OutlawSkills::SemVer.bump("0.1.0", "patch")
    assert_equal "0.2.0", OutlawSkills::SemVer.bump("0.1.0", "minor")
    assert_equal "1.0.0", OutlawSkills::SemVer.bump("0.1.0", "major")
    assert_equal "2.0.0", OutlawSkills::SemVer.bump("1.4.9", "major")
  end

  def test_non_semver_raises
    assert_raises(OutlawSkills::ReleaseError) { OutlawSkills::SemVer.bump("v1.0", "patch") }
    assert_raises(OutlawSkills::ReleaseError) { OutlawSkills::SemVer.bump("1.0.0-rc1", "patch") }
  end

  def test_bad_level_raises
    assert_raises(OutlawSkills::ReleaseError) { OutlawSkills::SemVer.bump("0.1.0", "huge") }
  end
end

class ReleaseMarketplaceSyncTest < Minitest::Test
  include ReleaseFixtures

  def test_updates_both_fields_with_minimal_diff
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "0.1.0")
      path = File.join(dir, ".claude-plugin", "marketplace.json")
      before = File.read(path)

      OutlawSkills::MarketplaceSync.write(path, "0.2.0")

      data = JSON.parse(File.read(path))
      assert_equal "0.2.0", data["metadata"]["version"]
      assert_equal "0.2.0", data["plugins"][0]["version"]

      changed = before.lines.zip(File.read(path).lines).reject { |a, b| a == b }
      assert_equal 2, changed.size, "only the two version lines should change, got: #{changed.inspect}"
      changed.each { |_, after| assert_match(/0\.2\.0/, after) }
    end
  end
end

class ReleaseTestGateTest < Minitest::Test
  def test_zero_tests_is_failure
    with_test_dir('require "minitest/autorun"') do |dir|
      refute OutlawSkills::TestGate.new(root: dir).pass?, "zero collected tests must fail the gate (R6 false-green guard)"
    end
  end

  def test_passing_test_passes
    body = <<~RB
      require "minitest/autorun"
      class GateOkTest < Minitest::Test
        def test_ok = assert(true)
      end
    RB
    with_test_dir(body) { |dir| assert OutlawSkills::TestGate.new(root: dir).pass? }
  end

  def test_failing_test_fails
    body = <<~RB
      require "minitest/autorun"
      class GateBadTest < Minitest::Test
        def test_bad = assert(false)
      end
    RB
    with_test_dir(body) { |dir| refute OutlawSkills::TestGate.new(root: dir).pass? }
  end

  private

  def with_test_dir(helper_body)
    Dir.mktmpdir do |dir|
      FileUtils.mkdir_p(File.join(dir, "test"))
      File.write(File.join(dir, "test", "test_helper.rb"), helper_body)
      yield dir
    end
  end
end

class ReleaseGitCleanTest < Minitest::Test
  def test_clean_tracked_ignores_untracked_files
    Dir.mktmpdir do |dir|
      init_repo(dir)
      File.write(File.join(dir, "scratch"), "y") # untracked, like ref/
      git = OutlawSkills::Git.new(root: dir)
      assert git.clean_tracked?, "untracked files must not block the release (R11)"

      File.write(File.join(dir, "a.txt"), "changed") # tracked modification
      refute git.clean_tracked?, "tracked modification must mark the tree dirty"
    end
  end

  private

  def init_repo(dir)
    system("git", "-C", dir, "init", "-q")
    system("git", "-C", dir, "config", "user.email", "t@example.com")
    system("git", "-C", dir, "config", "user.name", "Test")
    File.write(File.join(dir, "a.txt"), "x")
    system("git", "-C", dir, "add", "a.txt")
    system("git", "-C", dir, "commit", "-qm", "init")
  end
end

class ReleaserCoreTest < Minitest::Test
  include ReleaseFixtures

  def test_dry_run_changes_nothing
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "0.1.0")
      snapshot = tree_snapshot(dir)
      out = StringIO.new

      result = OutlawSkills::Releaser.new(
        root: dir, level: "patch", dry_run: true, out: out,
        git: FakeGit.new(clean: true), test_gate: FakeTestGate.new(pass: true), build: ->{}
      ).run

      assert_equal "0.1.1", result
      assert_equal snapshot, tree_snapshot(dir), "dry-run must not mutate any file"
      assert_match(/0\.1\.0 -> 0\.1\.1/, out.string)
    end
  end

  def test_dirty_tree_aborts_before_mutation
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "0.1.0")
      snapshot = tree_snapshot(dir)

      assert_raises(OutlawSkills::ReleaseError) do
        OutlawSkills::Releaser.new(
          root: dir, level: "patch", out: StringIO.new,
          git: FakeGit.new(clean: false), test_gate: FakeTestGate.new(pass: true), build: stamping_build(dir)
        ).run
      end

      assert_equal snapshot, tree_snapshot(dir), "no file should change when the tree is dirty"
    end
  end

  def test_successful_prepare_applies_and_keeps_invariant
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "0.1.0")

      OutlawSkills::Releaser.new(
        root: dir, level: "minor", out: StringIO.new,
        git: FakeGit.new(clean: true), test_gate: FakeTestGate.new(pass: true), build: stamping_build(dir)
      ).run

      locations = OutlawSkills::VersionLocations.new(root: dir)
      assert_equal "0.2.0", locations.version_file
      assert locations.consistent?, "all version locations must agree after a successful bump: #{locations.all.inspect}"
    end
  end

  def test_test_gate_failure_rolls_back
    Dir.mktmpdir do |dir|
      write_repo_fixture(dir, "0.1.0")
      git = FakeGit.new(clean: true)

      error = assert_raises(OutlawSkills::ReleaseError) do
        OutlawSkills::Releaser.new(
          root: dir, level: "patch", out: StringIO.new,
          git: git, test_gate: FakeTestGate.new(pass: false, output: "1 failure"), build: stamping_build(dir)
        ).run
      end

      assert_match(/rolled back/, error.message)
      assert_includes git.calls, [:restore, "VERSION", ".claude-plugin/marketplace.json", "dist"],
        "a failed test gate must restore the bump's tracked paths (R14)"
    end
  end

  private

  def tree_snapshot(dir)
    Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |p| File.file?(p) }.sort.to_h do |p|
      [p.sub(dir, ""), File.read(p)]
    end
  end
end
