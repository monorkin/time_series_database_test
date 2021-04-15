# frozen_string_literal: true

require 'active_support'
require 'terminal-table'

module TsTest
  class Reporter
    DEFAULT_OPTIONS = { float_precision: 6 }.freeze
    HEADINGS = [
      'Test case',
      'User',
      'System',
      'Total',
      'Real'
    ].freeze

    attr_reader :runner
    attr_reader :options

    def initialize(runner, options = {})
      @runner = runner
      @options = DEFAULT_OPTIONS.merge(options)
    end

    def print!
      puts name.upcase if name.present?

      table = Terminal::Table.new(
        headings: headings,
        rows: rows
      )

      puts table
    end

    def headings
      HEADINGS
    end

    def rows
      runner.results.map do |test_case, measurments|
        measurment = measurments.first
        [
          test_case,
          "#{measurment.utime.round(float_precision)}s",
          "#{measurment.stime.round(float_precision)}s",
          "#{measurment.total.round(float_precision)}s",
          "#{measurment.real.round(float_precision)}s"
        ]
      end
    end

    def name
      options[:name]
    end

    def float_precision
      options[:float_precision]
    end
  end
end
