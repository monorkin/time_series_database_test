# frozen_string_literal: true

require 'benchmark'

module TsTest
  class Runner
    attr_reader :options
    attr_reader :results

    def self.model(name, model_class = nil)
      @models ||= {}

      if model_class.nil?
        @models[name]
      else
        @models[name] = model_class
      end
    end

    def initialize(options = {})
      @results = {}
      @options = options
    end

    ############################################################################
    #                                TEST CASES                                #
    ############################################################################

    def ten_thousand_inserts
      10_000.times { event_model.random.save! }
    end

    def parallel_simple_reads_and_writes_with_min_records
      parallel_simple_reads_and_writes
    end

    def parallel_simple_reads_and_writes_with_max_records
      parallel_simple_reads_and_writes
    end

    def parallel_simple_reads_and_writes
      writers = TsTest.config.fetch(:parallel_writers).times.map do
        Thread.new do
          10_000.times { event_model.random.save! }
        end
      end

      readers = TsTest.config.fetch(:parallel_readers).times.map do
        Thread.new do
          10_000.times { event_model.order(id: :desc).first }
        end
      end

      # Wait for all threads to finish
      [*readers, *writers].each(&:join)
    end

    def parallel_complex_reads_and_writes_with_min_records
      parallel_complex_reads_and_writes
    end

    def parallel_complex_reads_and_writes_with_max_records
      parallel_complex_reads_and_writes
    end

    def parallel_complex_reads_and_writes
      writers = TsTest.config.fetch(:parallel_writers).times.map do
        Thread.new do
          10_000.times { event_model.random.save! }
        end
      end

      readers = TsTest.config.fetch(:parallel_readers).times.map do
        Thread.new do
          10_000.times do
            event_model
              .select('SUM(events.value), EXTRACT(year FROM events.created_at), COUNT(devices.id), COUNT(users.id)')
              .joins(:device, :user)
              .group('EXTRACT(year FROM events.created_at)')
          end
        end
      end

      # Wait for all threads to finish
      [*readers, *writers].each(&:join)
    end

    ############################################################################
    #                                UTILITIES                                 #
    ############################################################################

    def run_all
      TsTest.config.fetch(:test_cases, []).each { |case_name| run(case_name) }
    end

    def run(case_name)
      unless respond_to?(case_name)
        raise(NotImplementedError,
              "#{self.class} doesn't implement test case #{case_name}")
      end

      print "* Testing #{self.class}##{case_name}"
      results[case_name] ||= []

      start = Time.now.to_i

      begin
        call_if_responds_to(:prepare!) if setup?
        call_if_responds_to("#{case_name}_prepare!".to_sym)
        results[case_name] << Benchmark.measure(case_name) { public_send(case_name) }
      ensure
        call_if_responds_to("#{case_name}_teardown!".to_sym)
        call_if_responds_to(:teardown!) if setup?
      end

      finish = Time.now.to_i
      print " - took #{finish - start}s to prepare, test and teardown"
      puts

      true
    end

    private

    def call_if_responds_to(method_name)
      public_send(method_name) if respond_to?(method_name)
    end

    def setup?
      !!options[:setup]
    end

    def event_model
      self.class.model(:event) ||
        raise("#{self.class} didn't specify an Event model using `model :event, Event`")
    end
  end
end
