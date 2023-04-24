module MonitorOutdatedGems
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
