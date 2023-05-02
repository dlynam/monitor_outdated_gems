require "spec_helper"
require "./lib/monitor_outdated_gems"
require "rails"
require "active_support/core_ext/hash/indifferent_access"
require "active_support/core_ext/integer/time"

describe MonitorOutdatedGems::OutputOutdatedGems do
  before(:each) do
    MonitorOutdatedGems::INSTALLED_GEM_VERSIONS.clear
    allow(Rails).to receive(:env) { "development" }
  end

  after(:all) do
    File.delete(cached_versions_filepath)
  end

  def setup(installed_versions, latest_versions)
    installed_versions.each do |name, version|
      MonitorOutdatedGems::INSTALLED_GEM_VERSIONS[name] = version
    end
    @cached_versions = {:latest_versions=>latest_versions, :updated_at=>1.day.ago}

    yield if block_given?

    create_cached_versions_file(@cached_versions)
  end

  def create_cached_versions_file(cached_versions)
    cached_versions_filepath
      .yield_self{ |path| File.open(path, "w") }
      .yield_self{ |file| file.write(cached_versions.to_yaml); file; }
      .yield_self{ |file| file.close }
  end

  def cached_versions_filepath
    @cached_versions_filepath ||= File.join(File.dirname(__FILE__), "/monitor_outdated_gems.yml")
  end

  describe "#new" do
    it "should output an out of date message for a PATCH version" do
      setup({rspec: "3.11.4"}, {rspec: "3.11.5"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "PATCH"
        end
      end.to output("* The following gem is out of date:\n* rspec (3.11.4 < 3.11.5)\n").to_stdout
    end

    it "should output an out of date message for a PATCH version with 3 decimals" do
      setup({rspec: "3.11.4.4"}, {rspec: "3.11.4.7"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "PATCH"
        end
      end.to output("* The following gem is out of date:\n* rspec (3.11.4.4 < 3.11.4.7)\n").to_stdout
    end

    it "should not output an out of date message for a PATCH version" do
      setup({rspec: "3.11.5"}, {rspec: "3.11.5"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "PATCH"
        end
      end.to output("").to_stdout
    end

    it "should output an out of date message for a MINOR version" do
      setup({rspec: "3.11.4"}, {rspec: "3.12.1"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MINOR"
        end
      end.to output("* The following gem is out of date:\n* rspec (3.11.4 < 3.12.1)\n").to_stdout
    end

    it "should not output an out of date message for a MINOR version" do
      setup({rspec: "3.12.4"}, {rspec: "3.12.6"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MINOR"
        end
      end.to output("").to_stdout
    end

    it "should output an out of date message for a MAJOR version" do
      setup({rspec: "3.11.4"}, {rspec: "4.0.0"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MAJOR"
        end
      end.to output("* The following gem is out of date:\n* rspec (3.11.4 < 4.0.0)\n").to_stdout
    end

    it "should not output an out of date message for a MAJOR version" do
      setup({rspec: "3.11.4"}, {rspec: "3.12.15"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MAJOR"
        end
      end.to output("").to_stdout
    end

    it "should output an out of date message for a MAJOR version with PATCH monitoring" do
      setup({rspec: "3.11.4"}, {rspec: "4.12.15"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "PATCH"
        end
      end.to output("* The following gem is out of date:\n* rspec (3.11.4 < 4.12.15)\n").to_stdout
    end

    it "should output an out of date message for multiple gems" do
      setup({rspec: "3.11.4", browser: "1.5.6", strong_migrations: "3.4.5"},
            {rspec: "3.12.15", browser: "1.5.9", strong_migrations: "3.6.5"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MINOR"
          monitor "browser", versions: "PATCH"
          monitor "strong_migrations", versions: "MAJOR"
        end
      end.to output("* The following gems are out of date:\n* rspec (3.11.4 < 3.12.15)\n* browser (1.5.6 < 1.5.9)\n").to_stdout
    end

    it "should not output an out of date message for ignored gems" do
      setup({rspec: "3.11.4", browser: "1.5.6", strong_migrations: "3.4.5"},
            {rspec: "3.12.15", browser: "1.5.9", strong_migrations: "3.6.5"})
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MINOR", ignore: true
          monitor "browser", versions: "PATCH", ignore: true
          monitor "strong_migrations", versions: "MAJOR"
        end
      end.to output("").to_stdout
    end

    it "should add a newly monitored gem to the cached versions file" do
      setup({rspec: "3.12.15", strong_migrations: "3.6.5"},
            {rspec: "3.12.15"})
      filepath = cached_versions_filepath

      VCR.use_cassette("strong_migrations_request") do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MINOR"
          monitor "strong_migrations", versions: "MAJOR"
        end
      end

      cached_versions = cached_versions_filepath
        .yield_self{ |path| File.read(path) }
        .yield_self{ |file| YAML.load(file); }
      cached_versions.delete(:updated_at)

      expect(cached_versions).to eq({:latest_versions=>{:rspec=>"3.12.15",
                                                        :strong_migrations=>"1.4.4"}})
    end

    it "should gather new versions due to daily frequency" do
      setup({strong_migrations: "1.4.1"}, {strong_migrations: "1.4.1"}) do
        @cached_versions[:updated_at] = 3.days.ago
      end
      filepath = cached_versions_filepath

      expect do
        VCR.use_cassette("strong_migrations_request") do
          MonitorOutdatedGems::Config.new do
            set_cached_versions_filepath(filepath)
            set_frequency_default "daily"
            monitor "strong_migrations", versions: "PATCH"
          end
        end
      end.to output("* The following gem is out of date:\n* strong_migrations (1.4.1 < 1.4.4)\n").to_stdout
    end

    it "should output an error for monitoring a gem that is not installed" do
      filepath = cached_versions_filepath

      expect do
        MonitorOutdatedGems::Config.new do
          set_cached_versions_filepath(filepath)
          monitor "rspec", versions: "MINOR", ignore: false
        end
      end.to output("rspec is monitored by monitor_outdated_gems but is not installed\n").to_stdout
    end
  end
end
