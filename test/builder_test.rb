require_relative "test_helper"
require "json"
require "fileutils"
require "tmpdir"

class BuilderTest < Minitest::Test
  DIST = File.join(ROOT, "dist", "plugin")

  def setup
    @builder = OutlawSkills::Builder.new(root: ROOT)
    @builder.build
  end

  # Happy path: the single tree carries a valid manifest with correct identity.
  def test_manifest_exists_with_correct_identity
    manifest_path = File.join(DIST, ".claude-plugin", "plugin.json")
    assert File.exist?(manifest_path), "expected manifest at #{manifest_path}"
    manifest = JSON.parse(File.read(manifest_path))
    assert_equal "outlaw-skills", manifest["name"]
    assert_equal File.read(File.join(ROOT, "VERSION")).strip, manifest["version"]
    assert_equal "MIT", manifest["license"]
    assert manifest["description"].is_a?(String) && !manifest["description"].empty?
    # `category` belongs in the marketplace entry, not plugin.json (Claude warns otherwise).
    refute manifest.key?("category"), "category must not appear in plugin.json"
  end

  def test_skills_appear_in_dist
    %w[controller-patterns find-skills ruby-version].each do |skill|
      assert File.exist?(File.join(DIST, "skills", skill, "SKILL.md")),
        "expected #{skill}/SKILL.md in dist"
    end
  end

  # skill-audit ships verbatim — SKILL.md plus its full references/ set.
  def test_skill_audit_ships_with_references
    assert File.exist?(File.join(DIST, "skills", "skill-audit", "SKILL.md"))
    %w[decomposition lens-contradiction lens-redundancy lens-dilution load-bearing-guard output-format].each do |ref|
      assert File.exist?(File.join(DIST, "skills", "skill-audit", "references", "#{ref}.md")),
        "expected skill-audit/references/#{ref}.md in dist"
    end
  end

  # md-audit ships verbatim, including the bundled non-dot markdownlint config.
  def test_md_audit_ships_with_references
    assert File.exist?(File.join(DIST, "skills", "md-audit", "SKILL.md"))
    %w[safe-formatting.md typo-gate.md markdownlint-cli2.jsonc].each do |ref|
      assert File.exist?(File.join(DIST, "skills", "md-audit", "references", ref)),
        "expected md-audit/references/#{ref} in dist"
    end
  end

  def test_ruby_version_subdirectory_assets_copied
    assert File.exist?(File.join(DIST, "skills", "ruby-version", "scripts", "check.sh"))
    assert File.exist?(File.join(DIST, "skills", "ruby-version", "scripts", "install.sh"))
  end

  # Agents are copied verbatim — no tool-name translation, no frontmatter rewrite.
  def test_agents_appear_in_dist_verbatim
    %w[dhh-rails-reviewer kieran-rails-reviewer].each do |agent|
      dest = File.join(DIST, "agents", "#{agent}.agent.md")
      assert File.exist?(dest), "expected #{agent}.agent.md in dist"
      assert_equal File.read(File.join(ROOT, "src", "agents", "#{agent}.agent.md")),
                   File.read(dest), "agent must be copied verbatim (no translation)"
    end
  end

  # The plugin-native hook ships at the default hooks/ location, executable.
  def test_hook_ships_and_is_executable
    hooks_json = File.join(DIST, "hooks", "hooks.json")
    script = File.join(DIST, "hooks", "rails-gate.sh")
    assert File.exist?(hooks_json), "expected hooks/hooks.json in dist"
    assert JSON.parse(File.read(hooks_json)).dig("hooks", "PreToolUse"),
      "hooks.json must declare a PreToolUse hook"
    assert File.exist?(script), "expected hooks/rails-gate.sh in dist"
    assert File.executable?(script), "hook script must be executable"
  end

  def test_root_files_copied_to_dist
    %w[AGENTS.md LICENSE].each do |f|
      assert File.exist?(File.join(DIST, f)), "expected #{f} in dist root"
    end
  end

  # The old VS-Code-era Copilot layout must never reappear in the single tree.
  def test_no_legacy_vscode_artifacts
    refute File.exist?(File.join(DIST, ".github")), ".github layout must not be emitted"
    refute File.exist?(File.join(DIST, "copilot-instructions.md")), "copilot-instructions.md must not be emitted"
    refute File.exist?(File.join(DIST, "README.md")), "generated README must not be emitted"
  end

  # Edge case: empty src/skills/ -> valid plugin with zero skills (manifest still valid).
  def test_empty_skills_produces_valid_dist
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "src", "skills"))
      FileUtils.mkdir_p(File.join(tmp, "src", "agents"))
      File.write(File.join(tmp, "VERSION"), "0.1.0\n")
      OutlawSkills::Builder.new(root: tmp).build

      manifest = JSON.parse(File.read(File.join(tmp, "dist", "plugin", ".claude-plugin", "plugin.json")))
      assert_equal "outlaw-skills", manifest["name"]
      refute File.directory?(File.join(tmp, "dist", "plugin", "skills")),
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
