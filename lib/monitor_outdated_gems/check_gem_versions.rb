module MonitorOutdatedGems
  INSTALLED_GEM_VERSIONS = Gem::Specification.inject({}) {|hash, gem_spec|
    hash[gem_spec.name.to_sym] = gem_spec.version.to_s
    hash
  }.freeze
  VALID_VERSIONS_TO_MONITOR = ["PATCH", "MINOR", "MAJOR"].freeze
  DEFAULT_VERSIONS_TO_MONITOR = "MINOR".freeze
  DEFAULT_FREQUENCY = "monthly".freeze
  DEFAULT_CACHED_VERSIONS_PATH = Bundler.user_cache

  class Config
    attr_accessor :versions_to_monitor, :monitor_frequency
    attr_reader :to_monitor

    def initialize(&block)
      return unless is_rails_development_env? && block

      @versions_to_monitor = DEFAULT_VERSIONS_TO_MONITOR
      @monitor_frequency = DEFAULT_FREQUENCY
      @to_monitor = []

      instance_eval(&block)
      to_monitor.freeze

      perform
    end

    private

    def perform
      load_latest_versions
      output_outdated_gems
    end

    def load_latest_versions
      LoadLatestGemVersions.new(self).call
    end

    def output_outdated_gems
      OutputOutdatedGems.new(self).call
    end

    def set_frequency_default(frequency)
      self.monitor_frequency = frequency
    end

    def set_versions_default(versions)
      self.versions_to_monitor = versions
    end

    # method for loading gems to monitor in Rails initializer
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

    def is_rails_development_env?
      begin
        Module.const_get("Rails") &&
        Rails.env == "development"
      rescue NameError
        false
      end
    end

    def output_not_installed_message(gem_name)
      puts "#{gem_name} is monitored by monitor_outdated_gems but is not installed"
    end
  end

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

  class OutputOutdatedGems
    attr_reader :to_monitor

    def initialize(config)
      @to_monitor = config.to_monitor
    end

    def call
      return unless out_of_date_gems.any?

      puts first_line
      out_of_date_gems.each do |monitored_gem|
        puts "* #{monitored_gem.name} (#{monitored_gem.current_version} < #{monitored_gem.latest_version})"
      end
    end

    private

    def out_of_date_gems
      @out_of_date_gems ||= to_monitor.select{|monitored_gem| monitored_gem.out_of_date? }
    end

    def first_line
      if out_of_date_gems.count > 1
        "* The following gems are out of date:"
      else
        "* The following gem is out of date:"
      end
    end
  end

  class MonitoredGem
    attr_reader :name, :current_version, :versions_to_monitor
    attr_accessor :latest_version

    def initialize(name, options)
      @name = name
      @current_version = INSTALLED_GEM_VERSIONS[name.to_sym]
      @versions_to_monitor = options.fetch(:versions)
    end

    def out_of_date?
      case versions_to_monitor
      when 'MAJOR'
        newer_major_version?
      when 'MINOR'
        newer_minor_version?
      when 'PATCH'
        newer_patch_version?
      else
        false
      end
    end

    private

    def newer_major_version?
      newer_version_for_level?(0)
    end

    def newer_minor_version?
      newer_major_version? || newer_version_for_level?(1)
    end

    def newer_patch_version?
      newer_minor_version? || compare_patch_versions
    end

    def compare_patch_versions
      if current_version.split(".").size > 3
        if newer_version_for_level?(2)
          true
        else
          newer_version_for_level?(3)
        end
      else
        newer_version_for_level?(2)
      end
    end

    def newer_version_for_level?(num)
      if latest_version
        latest_version.split(".")[num].to_i > current_version.split(".")[num].to_i
      else
        false
      end
    end
  end
end
