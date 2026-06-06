require_relative "test_helper"
require "fileutils"
require "tmpdir"

# Covers the skill-diff skill: it builds into both targets with its bundled
# script intact, the pure tiered matcher resolves the right upstream dir
# offline, and the resolver handles the no-upstream / bad-input cases cleanly.
# Network-dependent paths (live `gh` resolution + fetch) are intentionally not
# exercised here so the suite stays green offline.
class SkillDiffTest < Minitest::Test
  CLAUDE_DIST  = File.join(ROOT, "dist", "claude")
  COPILOT_DIST = File.join(ROOT, "dist", "copilot")
  SCRIPT       = File.join(ROOT, "src", "skills", "skill-diff", "scripts", "compare.sh")

  def setup
    @builder = OutlawSkills::Builder.new(root: ROOT)
    @builder.build_target("claude")
    @builder.build_target("copilot")
  end

  # --- build / structure ----------------------------------------------------

  def test_skill_is_discovered_by_builder
    assert_includes @builder.skills.map(&:name), "skill-diff"
  end

  # The build's validate! does NOT enforce name/description, so we assert it.
  def test_skill_md_has_name_and_description
    fm = @builder.skills.find { |s| s.name == "skill-diff" }.frontmatter
    assert_equal "skill-diff", fm["name"]
    assert fm["description"].is_a?(String) && !fm["description"].empty?,
      "skill-diff SKILL.md must carry a non-empty description"
  end

  def test_bundled_script_ships_to_both_targets_executable
    claude_script  = File.join(CLAUDE_DIST,  "skills", "skill-diff", "scripts", "compare.sh")
    copilot_script = File.join(COPILOT_DIST, ".github", "skills", "skill-diff", "scripts", "compare.sh")
    assert File.exist?(claude_script),  "expected compare.sh in claude dist"
    assert File.exist?(copilot_script), "expected compare.sh in copilot dist"
    assert File.executable?(claude_script),  "compare.sh should keep its executable bit in claude dist"
    assert File.executable?(copilot_script), "compare.sh should keep its executable bit in copilot dist"
  end

  # --- pure matcher (offline, via --match-only stdin seam) ------------------

  # The real CompoundEngineering tree: ce-work collides with ce-work-beta and
  # ce-worktree under prefix/substring matching, and ships fixture SKILL.md files.
  CE_TREE = <<~PATHS
    plugins/compound-engineering/skills/ce-work/SKILL.md
    plugins/compound-engineering/skills/ce-work-beta/SKILL.md
    plugins/compound-engineering/skills/ce-worktree/SKILL.md
    plugins/compound-engineering/skills/ce-plan/SKILL.md
    tests/fixtures/skills/skill-one/SKILL.md
    tests/fixtures/build/default-skill/SKILL.md
  PATHS

  def test_matcher_resolves_ce_prefix_without_sibling_ambiguity
    assert_equal "plugins/compound-engineering/skills/ce-work/SKILL.md",
      match("work", CE_TREE)
  end

  def test_matcher_resolves_name_skew
    assert_equal "plugins/compound-engineering/skills/ce-plan/SKILL.md",
      match("plan", CE_TREE)
  end

  def test_matcher_prefers_exact_match
    tree = "skills/controller-patterns/SKILL.md\nskills/ce-controller-patterns/SKILL.md\n"
    assert_equal "skills/controller-patterns/SKILL.md", match("controller-patterns", tree)
  end

  def test_matcher_filters_test_fixtures
    # skill-one only exists under tests/fixtures, so it must not resolve.
    assert_equal "NONE", match("skill-one", CE_TREE)
  end

  def test_matcher_reports_none_when_absent
    assert_equal "NONE", match("nonexistent", CE_TREE)
  end

  def test_matcher_reports_ambiguous_on_duplicate_dirs
    tree = "skills/foo/SKILL.md\nplugins/x/skills/foo/SKILL.md\n"
    assert_equal "AMBIGUOUS", match("foo", tree)
  end

  # --- resolver behavior (offline; these paths fail before any gh call) -----

  def test_no_based_on_reports_cleanly
    out, status = run_cli("--resolve-only", "skill-diff")
    assert_equal 0, status, "no-based_on should exit 0"
    assert_match(/no upstream recorded/, out)
  end

  def test_invalid_skill_name_rejected
    _out, status = run_cli("../../etc")
    assert_equal 1, status, "path-traversal skill name must be rejected"
  end

  def test_missing_argument_prints_usage
    out, status = run_cli
    assert_equal 1, status
    assert_match(/usage/, out)
  end

  def test_legacy_alias_format_reports_cleanly
    with_temp_skill(based_on: "BogusAlias:thing") do |script, name|
      out, status = run_script(script, "--resolve-only", name)
      assert_equal 0, status, "unsupported based_on format should exit 0"
      assert_match(/unrecognized based_on format/, out)
      assert_match(/expected owner\/repo@skill/, out)
    end
  end

  def test_based_on_traversal_component_rejected
    with_temp_skill(based_on: "foo/bar@../../x") do |script, name|
      _out, status = run_script(script, "--resolve-only", name)
      assert_equal 1, status, "traversal in based_on component must be rejected before gh"
    end
  end

  private

  def match(target, tree)
    out, _ = run_script(SCRIPT, "--match-only", target, stdin: tree)
    out.strip
  end

  def run_cli(*args, stdin: nil)
    run_script(SCRIPT, *args, stdin: stdin)
  end

  # Returns [combined_output, exit_status].
  def run_script(script, *args, stdin: nil)
    cmd = (["bash", script] + args).map { |a| "'#{a}'" }.join(" ")
    cmd += " 2>&1"
    output =
      if stdin
        IO.popen(cmd, "r+") { |io| io.write(stdin); io.close_write; io.read }
      else
        IO.popen(cmd) { |io| io.read }
      end
    [output, $?.exitstatus]
  end

  # Builds a throwaway repo (src/skills/<name>/SKILL.md + a copy of compare.sh)
  # so the script's repo-root walk resolves to the temp dir, letting us feed
  # synthetic based_on values without touching the real source tree.
  def with_temp_skill(based_on:, name: "faketest")
    Dir.mktmpdir do |dir|
      skill_dir = File.join(dir, "src", "skills", name)
      FileUtils.mkdir_p(skill_dir)
      contents = +"---\nname: #{name}\ndescription: synthetic test skill\n"
      contents << "based_on: #{based_on}\n" if based_on
      contents << "---\n\nbody\n"
      File.write(File.join(skill_dir, "SKILL.md"), contents)

      script_dir = File.join(dir, "src", "skills", "skill-diff", "scripts")
      FileUtils.mkdir_p(script_dir)
      FileUtils.cp(SCRIPT, script_dir)
      yield File.join(script_dir, "compare.sh"), name
    end
  end
end
