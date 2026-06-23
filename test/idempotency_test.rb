require_relative "test_helper"
require "digest"

class IdempotencyTest < Minitest::Test
  DIST = File.join(ROOT, "dist", "plugin")

  # Two consecutive builds produce byte-identical output.
  def test_two_builds_produce_byte_identical_output
    builder = OutlawSkills::Builder.new(root: ROOT)
    builder.build
    first = tree_hashes(DIST)
    builder.build
    second = tree_hashes(DIST)
    assert_equal first, second, "build is not idempotent — dist tree differs across runs"
  end

  private

  def tree_hashes(dir)
    Dir.glob("#{dir}/**/*", File::FNM_DOTMATCH).select { |p| File.file?(p) }.sort.to_h do |p|
      [p.sub(dir, ""), Digest::SHA256.file(p).hexdigest]
    end
  end
end
