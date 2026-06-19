require_relative "test_helper"
require "outlaw_skills/release"
require "json"
require "fileutils"
require "tmpdir"

class ReleaseVersionLocationsTest < Minitest::Test
  # The load-bearing invariant (R4): in the real repo, VERSION, both
  # marketplace.json version fields, and the built plugin.json all agree.
  # This guards against the exact drift that motivated the release pipeline.
  def test_real_repo_versions_are_consistent
    locations = OutlawSkills::VersionLocations.new(root: ROOT)
    assert locations.consistent?,
      "version drift across locations: #{locations.all.inspect}"
  end

  def test_reads_each_location
    Dir.mktmpdir do |dir|
      write_fixture(dir, version_file: "1.2.3", marketplace_meta: "1.2.3",
                         marketplace_plugin: "1.2.3", plugin_json: "1.2.3")
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
      write_fixture(dir, version_file: "1.2.3", marketplace_meta: "1.2.3",
                         marketplace_plugin: "0.9.9", plugin_json: "1.2.3")
      refute OutlawSkills::VersionLocations.new(root: dir).consistent?
    end
  end

  def test_malformed_marketplace_raises_clear_error
    Dir.mktmpdir do |dir|
      write_fixture(dir, version_file: "1.0.0", marketplace_meta: "1.0.0",
                         marketplace_plugin: "1.0.0", plugin_json: "1.0.0")
      File.write(File.join(dir, ".claude-plugin", "marketplace.json"), "{ not json")
      error = assert_raises(OutlawSkills::ReleaseError) do
        OutlawSkills::VersionLocations.new(root: dir).marketplace_metadata_version
      end
      assert_match(/malformed/, error.message)
    end
  end

  def test_missing_plugin_json_directs_to_build
    Dir.mktmpdir do |dir|
      write_fixture(dir, version_file: "1.0.0", marketplace_meta: "1.0.0",
                         marketplace_plugin: "1.0.0", plugin_json: "1.0.0")
      FileUtils.rm_rf(File.join(dir, "dist"))
      error = assert_raises(OutlawSkills::ReleaseError) do
        OutlawSkills::VersionLocations.new(root: dir).plugin_json_version
      end
      assert_match(/bin\/build/, error.message)
    end
  end

  private

  def write_fixture(dir, version_file:, marketplace_meta:, marketplace_plugin:, plugin_json:)
    File.write(File.join(dir, "VERSION"), "#{version_file}\n")

    plugin_dir = File.join(dir, ".claude-plugin")
    FileUtils.mkdir_p(plugin_dir)
    marketplace = {
      "name" => "outlaw-skills",
      "metadata" => { "description" => "x", "version" => marketplace_meta },
      "plugins" => [{ "name" => "outlaw-skills", "version" => marketplace_plugin, "source" => "./dist/claude" }]
    }
    File.write(File.join(plugin_dir, "marketplace.json"), JSON.pretty_generate(marketplace) + "\n")

    dist_plugin_dir = File.join(dir, "dist", "claude", ".claude-plugin")
    FileUtils.mkdir_p(dist_plugin_dir)
    File.write(File.join(dist_plugin_dir, "plugin.json"),
               JSON.pretty_generate({ "name" => "outlaw-skills", "version" => plugin_json }) + "\n")
  end
end
