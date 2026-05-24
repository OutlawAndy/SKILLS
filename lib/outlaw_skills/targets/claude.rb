require "fileutils"
require "json"

module OutlawSkills
  module Targets
    class Claude
      NAME = "claude".freeze

      def initialize(builder)
        @builder = builder
        @dist_dir = File.join(builder.dist_root, "claude")
      end

      def build
        FileUtils.rm_rf(@dist_dir)
        FileUtils.mkdir_p(@dist_dir)
        write_manifest
        copy_skills
        copy_agents
        copy_root_files
      end

      private

      def write_manifest
        plugin_dir = File.join(@dist_dir, ".claude-plugin")
        FileUtils.mkdir_p(plugin_dir)
        manifest = Manifest.claude(version: @builder.version)
        File.write(
          File.join(plugin_dir, "plugin.json"),
          JSON.pretty_generate(manifest) + "\n"
        )
      end

      def copy_skills
        skills = @builder.skills_for(NAME)
        return if skills.empty?
        dest = File.join(@dist_dir, "skills")
        FileUtils.mkdir_p(dest)
        skills.each { |s| FileUtils.cp_r(s.path, File.join(dest, s.name)) }
      end

      def copy_agents
        agents = @builder.agents_for(NAME)
        return if agents.empty?
        dest = File.join(@dist_dir, "agents")
        FileUtils.mkdir_p(dest)
        agents.each { |a| FileUtils.cp(a.path, File.join(dest, File.basename(a.path))) }
      end

      def copy_root_files
        %w[AGENTS.md LICENSE].each do |name|
          src = File.join(@builder.root, name)
          FileUtils.cp(src, File.join(@dist_dir, name)) if File.exist?(src)
        end
      end
    end
  end
end
