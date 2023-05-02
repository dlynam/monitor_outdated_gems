module MonitorOutdatedGems
  class CachedVersionsFilepath

    # returns the default cached versions filepath which can
    # be overwritten in the Rails initializer
    def call
      check_for_monitor_directory
      return cached_versions_filepath
    end

    private

    def check_for_monitor_directory
      Dir.mkdir(monitor_directory_path) unless Dir.exist?(monitor_directory_path)
    end

    def cached_versions_filepath
      "#{monitor_directory_path}/#{default_filename}".freeze
    end

    def monitor_directory_path
      "#{bundler_cache_path}/monitor_outdated_gems"
    end

    # This is the path that Bundler uses to save cached gem info locally.
    # Ex: /Users/<username>/.bundle/cache/
    def bundler_cache_path
      Bundler.user_cache
    end

    def default_filename
      "#{Rails.root.to_s.split("/").last}.yml"
    end
  end
end
