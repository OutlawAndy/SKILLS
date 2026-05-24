require_relative "test_helper"
require "yaml"
require "fileutils"
require "tmpdir"
require "digest"

class CopilotTargetTest < Minitest::Test
  COPILOT_DIST = File.join(ROOT, "dist", "copilot")

  def setup
    @builder = OutlawSkills::Builder.new(root: ROOT)
    @builder.build_target("copilot")
  end

  # Happy path: dist tree shape per research spec.
  def test_copilot_dist_has_expected_top_level_layout
    assert File.file?(File.join(COPILOT_DIST, ".github", "copilot-instructions.md"))
    assert File.directory?(File.join(COPILOT_DIST, ".github", "chatmodes"))
    assert File.directory?(File.join(COPILOT_DIST, ".github", "prompts"))
    assert File.file?(File.join(COPILOT_DIST, "README.md"))
  end

  def test_one_chatmode_per_agent
    %w[dhh-rails-reviewer kieran-rails-reviewer].each do |name|
      path = File.join(COPILOT_DIST, ".github", "chatmodes", "#{name}.chatmode.md")
      assert File.exist?(path), "expected #{path}"
    end
  end

  def test_one_prompt_per_skill
    %w[controller-patterns find-skills ruby-version].each do |name|
      path = File.join(COPILOT_DIST, ".github", "prompts", "#{name}.prompt.md")
      assert File.exist?(path), "expected #{path}"
    end
  end

  def test_top_level_instructions_lists_prompts_and_chatmodes
    content = File.read(File.join(COPILOT_DIST, ".github", "copilot-instructions.md"))
    assert_includes content, "/controller-patterns"
    assert_includes content, "/find-skills"
    assert_includes content, "/ruby-version"
    assert_includes content, "dhh-rails-reviewer"
    assert_includes content, "kieran-rails-reviewer"
  end

  def test_chatmode_frontmatter_translates_tools_and_drops_color
    fm = read_frontmatter(File.join(COPILOT_DIST, ".github", "chatmodes", "dhh-rails-reviewer.chatmode.md"))
    assert fm["description"], "expected description in chatmode frontmatter"
    assert_includes fm["tools"], "codebase"
    assert_includes fm["tools"], "search"
    assert_includes fm["tools"], "runCommands"
    refute fm.key?("color"), "color must not appear in Copilot chatmode frontmatter"
    refute_equal "inherit", fm["model"], "Claude `model: inherit` must not pass through"
  end

  def test_chatmode_tools_are_deduped_after_translation
    fm = read_frontmatter(File.join(COPILOT_DIST, ".github", "chatmodes", "dhh-rails-reviewer.chatmode.md"))
    # Grep and Glob both map to "search" — must not appear twice.
    assert_equal fm["tools"].length, fm["tools"].uniq.length
  end

  def test_prompt_frontmatter_has_mode_and_description
    fm = read_frontmatter(File.join(COPILOT_DIST, ".github", "prompts", "controller-patterns.prompt.md"))
    assert_equal "agent", fm["mode"]
    assert fm["description"]
  end

  # Idempotency: build twice, no diff.
  def test_two_copilot_builds_produce_byte_identical_output
    @builder.build_target("copilot")
    first = tree_hashes(COPILOT_DIST)
    @builder.build_target("copilot")
    second = tree_hashes(COPILOT_DIST)
    assert_equal first, second
  end

  # Edge: skill with targets: [claude] is excluded from Copilot dist.
  def test_claude_only_skill_does_not_appear_in_copilot
    Dir.mktmpdir do |tmp|
      FileUtils.mkdir_p(File.join(tmp, "src", "skills", "claude-only"))
      FileUtils.mkdir_p(File.join(tmp, "src", "skills", "both"))
      FileUtils.mkdir_p(File.join(tmp, "src", "agents"))
      File.write(File.join(tmp, "VERSION"), "0.1.0\n")
      File.write(File.join(tmp, "src", "skills", "claude-only", "SKILL.md"),
                 "---\nname: claude-only\ndescription: c\ntargets: [claude]\n---\nbody\n")
      File.write(File.join(tmp, "src", "skills", "both", "SKILL.md"),
                 "---\nname: both\ndescription: b\n---\nbody\n")
      OutlawSkills::Builder.new(root: tmp).build_target("copilot")

      assert File.exist?(File.join(tmp, "dist", "copilot", ".github", "prompts", "both.prompt.md"))
      refute File.exist?(File.join(tmp, "dist", "copilot", ".github", "prompts", "claude-only.prompt.md"))
    end
  end

  private

  def read_frontmatter(path)
    match = /\A---\s*\n(.*?\n)---\s*\n/m.match(File.read(path, encoding: "UTF-8"))
    raise "no frontmatter in #{path}" unless match
    YAML.safe_load(match[1], permitted_classes: [Symbol], aliases: false)
  end

  def tree_hashes(dir)
    Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |p| File.file?(p) }.sort.to_h do |p|
      [p.sub(dir, ""), Digest::SHA256.file(p).hexdigest]
    end
  end
end
