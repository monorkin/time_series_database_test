# frozen_string_literal: true

require 'active_support'

module TsTest
  class Tester
    DEFAULT_OPTIONS = { prepare: true, teardown: true }.freeze

    attr_reader :database
    attr_reader :options

    def self.for(database_name, options = {})
      new(
        database: database_name,
        options: DEFAULT_OPTIONS.merge(options)
      )
    end

    def initialize(database:, options: {})
      @database = database&.to_s&.downcase&.to_sym
      @options = options
    end

    def run(case_name, print_result: true)
      return if skip_tests?

      runner.run(case_name&.to_s&.downcase&.to_sym)

      print_result! if print_result
    end

    def run_all
      puts "Running all tests for #{database}" if verbose?
      original_values = runner.options.slice(:prepare, :teardown)
      runner.options.merge!(prepare: false, teardown: false)

      if runner.respond_to?(:prepare!) && original_values[:prepare]
        puts 'Preparing the database' if verbose?
        runner.prepare!
      end

      TsTest.config.fetch(:test_cases).each do |name|
        run(name, print_result: false)
      end

      if runner.respond_to?(:teardown!) && original_values[:teardown]
        puts 'Tearing down the database' if verbose?
        runner.teardown!
      end

      runner.options.merge!(original_values)

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

    def verbose?
      !!options[:verbose]
    end

    def skip_tests?
      !!options[:skip_tests]
    end
  end
end
