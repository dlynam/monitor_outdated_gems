module MonitorOutdatedGems
  class OutputOutdatedGems
    def call
      return unless out_of_date_gems.any?

      puts first_line
      out_of_date_gems.each do |monitored_gem|
        puts "* #{monitored_gem.name} (#{monitored_gem.current_version} < #{monitored_gem.latest_version})"
      end
    end

    private

    def to_monitor
      @to_monitor ||= MonitorOutdatedGems.config.to_monitor
    end

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
end
