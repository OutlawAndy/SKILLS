require_relative "test_helper"
require "fileutils"
require "tmpdir"

# Covers U5 acceptance criteria: `targets:` frontmatter filtering.
class TargetsTest < Minitest::Test
  def make_root(skills:, version: "0.1.0")
    tmp = Dir.mktmpdir
    FileUtils.mkdir_p(File.join(tmp, "src", "agents"))
    File.write(File.join(tmp, "VERSION"), "#{version}\n")
    skills.each do |name, frontmatter_yaml|
      dir = File.join(tmp, "src", "skills", name)
      FileUtils.mkdir_p(dir)
      File.write(File.join(dir, "SKILL.md"), "---\n#{frontmatter_yaml}---\n\nbody.\n")
    end
    tmp
  end

  def test_skill_with_no_targets_field_defaults_to_all_targets
    root = make_root(skills: { "all-by-default" => "name: all-by-default\ndescription: x\n" })
    builder = OutlawSkills::Builder.new(root: root)
    assert_equal OutlawSkills::TARGETS.sort, builder.skills.first.targets.sort
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_skill_with_claude_only_target_is_excluded_from_copilot
    root = make_root(skills: {
      "claude-only" => "name: claude-only\ndescription: x\ntargets: [claude]\n",
      "both"        => "name: both\ndescription: x\ntargets: [claude, copilot]\n",
    })
    builder = OutlawSkills::Builder.new(root: root)
    assert_equal %w[both claude-only], builder.skills_for("claude").map(&:name).sort
    assert_equal %w[both],              builder.skills_for("copilot").map(&:name).sort
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_unknown_target_is_warned_but_not_fatal_when_at_least_one_recognized
    root = make_root(skills: {
      "with-unknown" => "name: with-unknown\ndescription: x\ntargets: [claude, windsurf]\n"
    })
    # Capture stderr
    old_stderr = $stderr
    $stderr = StringIO.new
    builder = OutlawSkills::Builder.new(root: root)
    skill = builder.skills.first
    assert_equal ["claude"], skill.targets
    assert_includes $stderr.string, "windsurf"
  ensure
    $stderr = old_stderr if old_stderr
    FileUtils.rm_rf(root) if root
  end

  def test_empty_targets_array_raises_with_file_path
    root = make_root(skills: { "empty-targets" => "name: empty-targets\ndescription: x\ntargets: []\n" })
    err = assert_raises(OutlawSkills::BuildError) { OutlawSkills::Builder.new(root: root).skills }
    assert_includes err.message, "empty-targets"
    assert_includes err.message.downcase, "cannot be empty"
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_targets_with_no_recognized_entries_raises
    root = make_root(skills: { "all-unknown" => "name: all-unknown\ndescription: x\ntargets: [windsurf]\n" })
    err = assert_raises(OutlawSkills::BuildError) { OutlawSkills::Builder.new(root: root).skills }
    assert_includes err.message, "all-unknown"
    assert_includes err.message.downcase, "no known targets"
  ensure
    FileUtils.rm_rf(root) if root
  end

  def test_targets_must_be_an_array
    root = make_root(skills: { "scalar-targets" => "name: scalar-targets\ndescription: x\ntargets: claude\n" })
    err = assert_raises(OutlawSkills::BuildError) { OutlawSkills::Builder.new(root: root).skills }
    assert_includes err.message, "scalar-targets"
    assert_includes err.message.downcase, "must be an array"
  ensure
    FileUtils.rm_rf(root) if root
  end
end
