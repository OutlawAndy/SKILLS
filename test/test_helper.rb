require "minitest/autorun"
$LOAD_PATH.unshift File.expand_path("../lib", __dir__)
require "outlaw_skills/builder"

ROOT = File.expand_path("..", __dir__)

Dir['./*_test.rb'].each { |f| require_relative f }
