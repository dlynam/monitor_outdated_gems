module MonitorOutdatedGems
  INSTALLED_GEM_VERSIONS = Gem::Specification.inject({}) {|hash, gem_spec|
    hash[gem_spec.name.to_sym] = gem_spec.version.to_s
    hash
  }

  VALID_VERSIONS_TO_MONITOR = ["PATCH", "MINOR", "MAJOR"].freeze
  DEFAULT_VERSIONS_TO_MONITOR = "MINOR".freeze
  DEFAULT_FREQUENCY = "monthly".freeze
end
