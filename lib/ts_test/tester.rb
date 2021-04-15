# frozen_string_literal: true

require 'active_support'

module TsTest
  class Tester
    attr_reader :database
    attr_reader :options

    def self.for(database_name, options = { setup: true })
      new(database: database_name, options: options)
    end

    def initialize(database:, options: {})
      @database = database&.to_s&.downcase&.to_sym
      @options = options
    end

    def run(case_name, print_result: true)
      runner.run(case_name&.to_s&.downcase&.to_sym)
      print_result! if print_result
    end

    def run_all
      original_value = runner.options[:setup]
      runner.options[:setup] = false

      runner.prepare! if runner.respond_to?(:prepare!)
      TsTest.config.fetch(:test_cases).each { |name| run(name, print_result: false) }
      runner.teardown! if runner.respond_to?(:teardown!)

      runner.options[:setup] = original_value

      print_result!
    end

    private

    def runner
      @runner ||= begin
        runner_class =
          "TsTest::Runners::#{database.to_s.camelize}Runner".safe_constantize
        raise("No runner found for #{database.to_s.camelize}") unless runner_class

        runner_class.new(options)
      end
    end

    def print_result!
      Reporter.new(runner, name: database).print!
    end
  end
end
