module MonitorOutdatedGems
  class LoadLatestGemVersions
    attr_reader :to_monitor, :monitor_frequency, :cached_versions

    def initialize(config)
      @to_monitor = config.to_monitor
      @monitor_frequency = config.monitor_frequency
      @cached_versions = return_cached_versions
    end

    def call
      if cached_versions.present?
        if time_to_refresh_versions?
          get_latest_versions
        else
          load_cached_versions
          save_versions_cache
        end
      else
        get_latest_versions
      end
    end

    private

    def time_to_refresh_versions?
      cached_versions[:updated_at] < frequency_date
    end

    def frequency_date
      @frequency_date ||= begin
        case monitor_frequency
        when "monthly"
          1.month.ago
        when "weekly"
          1.week.ago
        when "daily"
          1.day.ago
        end
      end
    end

    def load_cached_versions
      to_monitor.each do |monitored_gem|
        latest_version = cached_versions[:latest_versions][monitored_gem.name.to_sym]
        if latest_version
          monitored_gem.latest_version = latest_version
        else
          get_latest_remote_version(monitored_gem)
        end
      end
    end

    def get_latest_versions
      reset_cached_versions
      load_latest_versions
      save_versions_cache
    end

    def reset_cached_versions
      cached_versions[:latest_versions] = {}
      cached_versions[:updated_at] = Time.now
    end

    def load_latest_versions
      to_monitor.each do |monitored_gem|
        get_latest_remote_version(monitored_gem)
      rescue => e
        puts "Error fetching gem version: #{e}"
      end
    end

    def get_latest_remote_version(monitored_gem)
      latest_version = Gem.latest_version_for(monitored_gem.name).to_s
      cached_versions[:latest_versions][monitored_gem.name.to_sym] = latest_version
      monitored_gem.latest_version = latest_version
    end

    def save_versions_cache
      cached_versions_file_path
        .yield_self{ |path| File.open(path, "w") }
        .yield_self{ |file| file.write(cached_versions.to_yaml) }
    end

    def return_cached_versions
      if File.exists?(cached_versions_file_path)
        cached_versions_file_path
          .yield_self{ |path| File.read(path) }
          .yield_self{ |file| YAML.load(file) }
      else
        {}
      end
    end

    def cached_versions_file_path
      @cached_versions_file_path ||= "#{DEFAULT_CACHED_VERSIONS_PATH}/#{cached_versions_file_name}".freeze
    end

    def cached_versions_file_name
      @cached_versions_file_name ||= "monitor_outdated_gems.yml"
    end
  end
end
