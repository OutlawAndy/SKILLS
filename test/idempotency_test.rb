require_relative "test_helper"
require "digest"

class IdempotencyTest < Minitest::Test
  CLAUDE_DIST = File.join(ROOT, "dist", "claude")

  # Covers AE1: two consecutive builds produce byte-identical output.
  def test_two_builds_produce_byte_identical_output
    builder = OutlawSkills::Builder.new(root: ROOT)
    builder.build_target("claude")
    first = tree_hashes(CLAUDE_DIST)
    builder.build_target("claude")
    second = tree_hashes(CLAUDE_DIST)
    assert_equal first, second, "build is not idempotent — dist tree differs across runs"
  end

  private

  def tree_hashes(dir)
    Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |p| File.file?(p) }.sort.to_h do |p|
      [p.sub(dir, ""), Digest::SHA256.file(p).hexdigest]
    end
  end
end
