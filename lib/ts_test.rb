# frozen_string_literal: true

require 'yaml'
require 'active_record'
require 'active_support'
require 'zeitwerk'

loader = Zeitwerk::Loader.for_gem
loader.setup

module TsTest
  def self.config
    @config ||= YAML.load_file('./config.yml').deep_symbolize_keys
  end

  def self.test(database)
    Tester.for(database).run_all
  end

  def self.test_all
    config.fetch(:databases, {}).each_key { |database| test(database) }
  end
end

loader.eager_load
