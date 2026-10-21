require_relative "test_helper"
require "json"
require "open3"
require "tmpdir"

class PrReviewGateTest < Minitest::Test
  SCRIPT = File.join(ROOT, "src", "hooks", "pr-review-gate.sh")

  def setup
    @tmp = Dir.mktmpdir
    @repo = File.join(@tmp, "app")
    origin = File.join(@tmp, "origin.git")
    git @tmp, "init", "-q", "--bare", "-b", "main", origin
    git @tmp, "init", "-q", "-b", "main", @repo
    commit "Gemfile", "gem 'rails', '~> 8.1'\n"
    git @repo, "remote", "add", "origin", origin
    git @repo, "push", "-q", "origin", "main"
    git @repo, "remote", "set-head", "origin", "main"
    git @repo, "switch", "-q", "-c", "feature"
  end

  def teardown = FileUtils.rm_rf(@tmp)

  def test_blocks_first_pr_per_commit_naming_the_governing_skills
    commit "app/controllers/widgets_controller.rb", "class WidgetsController; end\n"
    commit "app/views/widgets/index.html.slim", "h1 Widgets\n"

    reason = gate.fetch("reason")
    assert_includes reason, "controller-patterns, frontend-patterns"
    assert_nil gate, "a retry at the same commit passes through"

    commit "app/controllers/widgets_controller.rb", "class WidgetsController < ApplicationController; end\n"
    assert gate, "a fix commit re-arms the gate"
  end

  def test_passes_diffs_without_rails_shaped_paths
    commit "README.md", "docs\n"
    assert_nil gate
  end

  def test_passes_other_commands
    commit "app/controllers/widgets_controller.rb", "class WidgetsController; end\n"
    assert_nil gate("gh pr view 12")
    assert gate("git push -u origin HEAD && gh pr create --fill")
  end

  def test_passes_non_rails_repos
    commit "Gemfile", "gem 'sinatra'\n"
    commit "app/controllers/widgets_controller.rb", "class WidgetsController; end\n"
    assert_nil gate
  end

  private

  def gate(command = "gh pr create --fill")
    payload = { tool_name: "Bash", tool_input: { command: }, cwd: @repo, session_id: "test" }.to_json
    out, err, status = Open3.capture3({ "TMPDIR" => @tmp }, SCRIPT, stdin_data: payload)
    assert status.success?, "hook exited #{status.exitstatus}: #{err}"
    JSON.parse(out) unless out.strip.empty?
  end

  def commit(path, content)
    file = File.join(@repo, path)
    FileUtils.mkdir_p(File.dirname(file))
    File.write(file, content)
    git @repo, "add", path
    git @repo, "-c", "user.name=t", "-c", "user.email=t@t", "-c", "commit.gpgsign=false", "commit", "-q", "-m", path
  end

  def git(dir, *args)
    _, err, status = Open3.capture3("git", "-C", dir, *args)
    raise err unless status.success?
  end
end
