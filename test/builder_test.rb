require_relative "test_helper"
require "json"
require "fileutils"
require "tmpdir"

class BuilderTest < Minitest::Test
  CLAUDE_DIST = File.join(ROOT, "dist", "claude")

  def setup
    @builder = OutlawSkills::Builder.new(root: ROOT)
    @builder.build_target("claude")
  end

  # Happy path: Covers AE1 (build emits valid plugin from the U2 corpus).
  def test_claude_manifest_exists_with_correct_identity
    manifest_path = File.join(CLAUDE_DIST, ".claude-plugin", "plugin.json")
    assert File.exist?(manifest_path), "expected manifest at #{manifest_path}"
    manifest = JSON.parse(File.read(manifest_path))
    assert_equal "outlaw-skills", manifest["name"]
    assert_equal File.read(File.join(ROOT, "VERSION")).strip, manifest["version"]
    assert_equal "MIT", manifest["license"]
    assert manifest["description"].is_a?(String) && !manifest["description"].empty?
  end

  def test_skills_appear_in_dist
    %w[controller-patterns find-skills ruby-version].each do |skill|
      assert File.exist?(File.join(CLAUDE_DIST, "skills", skill, "SKILL.md")),
        "expected #{skill}/SKILL.md in dist"
    end
  end

  # skill-audit ships to both targets verbatim (SKILL.md + references/) and is
  # listed in the Copilot always-on digest.
  def test_skill_audit_builds_into_both_targets_and_digest
    @builder.build_target("copilot")
    copilot_dist = File.join(ROOT, "dist", "copilot")

    assert File.exist?(File.join(CLAUDE_DIST, "skills", "skill-audit", "SKILL.md")),
      "expected skill-audit/SKILL.md in claude dist"
    assert File.exist?(File.join(copilot_dist, ".github", "skills", "skill-audit", "SKILL.md")),
      "expected skill-audit/SKILL.md in copilot dist"

    %w[decomposition lens-contradiction lens-redundancy lens-dilution load-bearing-guard output-format].each do |ref|
      assert File.exist?(File.join(CLAUDE_DIST, "skills", "skill-audit", "references", "#{ref}.md")),
        "expected skill-audit/references/#{ref}.md in claude dist"
      assert File.exist?(File.join(copilot_dist, ".github", "skills", "skill-audit", "references", "#{ref}.md")),
        "expected skill-audit/references/#{ref}.md in copilot dist"
    end

    digest = File.read(File.join(copilot_dist, ".github", "copilot-instructions.md"))
    assert_includes digest, "skill-audit"
  end

  # md-audit ships to both targets verbatim (SKILL.md + references/, including
  # the bundled non-dot markdownlint-cli2 config) and is listed in the digest.
  def test_md_audit_builds_into_both_targets_and_digest
    @builder.build_target("copilot")
    copilot_dist = File.join(ROOT, "dist", "copilot")

    assert File.exist?(File.join(CLAUDE_DIST, "skills", "md-audit", "SKILL.md")),
      "expected md-audit/SKILL.md in claude dist"
    assert File.exist?(File.join(copilot_dist, ".github", "skills", "md-audit", "SKILL.md")),
      "expected md-audit/SKILL.md in copilot dist"

    %w[safe-formatting.md typo-gate.md markdownlint-cli2.jsonc].each do |ref|
      assert File.exist?(File.join(CLAUDE_DIST, "skills", "md-audit", "references", ref)),
        "expected md-audit/references/#{ref} in claude dist"
      assert File.exist?(File.join(copilot_dist, ".github", "skills", "md-audit", "references", ref)),
        "expected md-audit/references/#{ref} in copilot dist"
    end

    digest = File.read(File.join(copilot_dist, ".github", "copilot-instructions.md"))
    assert_includes digest, "md-audit"
  end

  def test_ruby_version_subdirectory_assets_copied
    assert File.exist?(File.join(CLAUDE_DIST, "skills", "ruby-version", "scripts", "check.sh"))
    assert File.exist?(File.join(CLAUDE_DIST, "skills", "ruby-version", "scripts", "install.sh"))
  end

  def test_agents_appear_in_dist
    %w[dhh-rails-reviewer kieran-rails-reviewer].each do |agent|
      assert File.exist?(File.join(CLAUDE_DIST, "agents", "#{agent}.agent.md")),
        "expected #{agent}.agent.md in dist"
    end
  end

  def test_root_files_copied_to_dist
    %w[AGENTS.md LICENSE].each do |f|
      assert File.exist?(File.join(CLAUDE_DIST, f)), "expected #{f} in dist root"
    end
  end

  # Edge case: empty src/skills/ -> valid plugin with zero skills (manifest still valid).
  def test_empty_skills_produces_valid_dist
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "src", "skills"))
      FileUtils.mkdir_p(File.join(tmp, "src", "agents"))
      File.write(File.join(tmp, "VERSION"), "0.1.0\n")
      builder = OutlawSkills::Builder.new(root: tmp)
      builder.build_target("claude")

      manifest = JSON.parse(File.read(File.join(tmp, "dist", "claude", ".claude-plugin", "plugin.json")))
      assert_equal "outlaw-skills", manifest["name"]
      refute File.directory?(File.join(tmp, "dist", "claude", "skills")),
        "empty skills source should not produce a dist skills/ directory"
    end
  end

  # Error path: malformed YAML frontmatter fails with the file path in the message.
  def test_malformed_frontmatter_raises_build_error_with_file_path
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "src", "skills", "bad"))
      File.write(File.join(tmp, "VERSION"), "0.1.0\n")
      bad_skill_path = File.join(tmp, "src", "skills", "bad", "SKILL.md")
      File.write(bad_skill_path, "---\nname: bad\n  description: : :\n---\nbody\n")

      err = assert_raises(OutlawSkills::BuildError) do
        OutlawSkills::Builder.new(root: tmp).skills
      end
      assert_includes err.message, bad_skill_path
      assert_includes err.message.downcase, "malformed yaml frontmatter"
    end
  end
end
