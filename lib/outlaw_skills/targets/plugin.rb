require "fileutils"
require "json"

module OutlawSkills
  module Targets
    # Emits the single dist/plugin/ tree consumed natively by both Claude Code
    # and Copilot CLI:
    #
    #   .claude-plugin/plugin.json   manifest (the one location both tools read)
    #   skills/<name>/SKILL.md       verbatim skill directory copies (+ bundled files)
    #   agents/<name>.agent.md       verbatim agent copies (Claude-native frontmatter;
    #                                Copilot maps Read->read, Bash->execute, and a
    #                                non-empty tools list restricts — never grants —
    #                                so the read-only reviewers stay read-only there)
    #   hooks/hooks.json + scripts   plugin-native hooks. Claude-format; Claude-effective.
    #                                Copilot reads the same tree but its plugin
    #                                preToolUse support differs (see plan RK2).
    #   AGENTS.md, LICENSE           copied verbatim from repo root
    #
    # No per-tool conversion is performed — one tree, copied verbatim.
    class Plugin
      def initialize(builder)
        @builder = builder
        @dist_dir = File.join(builder.dist_root, "plugin")
      end

      def build
        FileUtils.rm_rf(@dist_dir)
        FileUtils.mkdir_p(@dist_dir)
        write_manifest
        copy_skills
        copy_agents
        copy_hooks
        copy_root_files
      end

      private

      def write_manifest
        plugin_dir = File.join(@dist_dir, ".claude-plugin")
        FileUtils.mkdir_p(plugin_dir)
        manifest = Manifest.build(version: @builder.version)
        File.write(
          File.join(plugin_dir, "plugin.json"),
          JSON.pretty_generate(manifest) + "\n"
        )
      end

      def copy_skills
        skills = @builder.skills
        return if skills.empty?
        dest = File.join(@dist_dir, "skills")
        FileUtils.mkdir_p(dest)
        skills.each { |s| FileUtils.cp_r(s.path, File.join(dest, s.name)) }
      end

      def copy_agents
        agents = @builder.agents
        return if agents.empty?
        dest = File.join(@dist_dir, "agents")
        FileUtils.mkdir_p(dest)
        agents.each { |a| FileUtils.cp(a.path, File.join(dest, File.basename(a.path))) }
      end

      def copy_hooks
        src = @builder.hooks_src
        return unless File.directory?(src)
        dest = File.join(@dist_dir, "hooks")
        FileUtils.mkdir_p(dest)
        Dir.glob(File.join(src, "*")).sort.each { |entry| FileUtils.cp_r(entry, dest) }
        # Hook scripts must be executable when the host tool invokes them.
        Dir.glob(File.join(dest, "*.sh")).each { |f| FileUtils.chmod(0o755, f) }
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
