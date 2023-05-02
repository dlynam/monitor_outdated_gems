module MonitorOutdatedGems
  class << self
    attr_accessor :config
  end

  class Config
    attr_accessor :versions_to_monitor, :monitor_frequency, :cached_versions_filepath
    attr_reader :to_monitor

    def initialize(&block)
      return if !is_rails_dev_env? || block.nil?

      @versions_to_monitor = DEFAULT_VERSIONS_TO_MONITOR
      @monitor_frequency = DEFAULT_FREQUENCY
      @cached_versions_filepath = CachedVersionsFilepath.new.call
      @to_monitor = []

      instance_eval(&block)
      to_monitor.freeze

      set_config
      perform
    end

    private

    def set_config
      MonitorOutdatedGems.config = self
    end

    def perform
      load_latest_versions
      output_outdated_gems
    end

    def load_latest_versions
      LoadLatestGemVersions.new.call
    end

    def output_outdated_gems
      OutputOutdatedGems.new.call
    end

    def set_frequency_default(frequency)
      self.monitor_frequency = frequency
    end

    def set_versions_default(versions)
      self.versions_to_monitor = versions
    end

    def set_cached_versions_filepath(filepath)
      self.cached_versions_filepath = filepath
    end

    # Method for loading gems to monitor in Rails initializer.
    def monitor(gem_name, options={})
      options = HashWithIndifferentAccess.new(options)
      options[:versions] = versions_to_monitor if !version_valid?(options)

      if gem_installed?(gem_name)
        unless options[:ignore]
          to_monitor.push(MonitoredGem.new(gem_name, options))
        end
      else
        output_not_installed_message(gem_name)
      end
    end

    def gem_installed?(gem_name)
      INSTALLED_GEM_VERSIONS[gem_name.to_sym]
    end

    def version_valid?(options)
      VALID_VERSIONS_TO_MONITOR.include?(options[:versions])
    end

    def output_not_installed_message(gem_name)
      puts "#{gem_name} is monitored by monitor_outdated_gems but is not installed"
    end

    def is_rails_dev_env?
      rails_loaded? && Rails.env == "development"
    end

    def rails_loaded?
      begin
        Module.const_get("Rails") && true
      rescue NameError
        false
      end
    end
  end
end
