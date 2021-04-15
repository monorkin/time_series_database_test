# frozen_string_literal: true

require 'benchmark'
require 'securerandom'
require 'uri'

module TsTest
  class Runner
    attr_reader :options
    attr_reader :results

    def self.execute(connection_options, sql)
      model = Class.new(ActiveRecord::Base) do
        self.abstract_class = true
      end

      const_name = "Model#{SecureRandom.hex(16)}"
      const_set(const_name, model)

      opts = connection_options.deep_dup
      if opts.key?(:url)
        uri = URI(opts[:url])
        uri.path = ''
        opts[:url] = uri.to_s
      end
      opts[:database] = nil if opts.key?(:database)

      model.establish_connection(opts)
      model.connection.execute(sql)
    end

    def self.build_models_for(parent_model_class)
      @parent_model = parent_model_class

      class_eval <<-RUBY, __FILE__, __LINE__ + 1
        class User < #{@parent_model}
          self.table_name = 'users'

          has_many :devices
          has_many :events, through: :devices

          def self.random
            new(
              name: SecureRandom.hex,
              created_at: rand(360_000...540_000).hours.ago
            )
          end
        end

        class Device < #{@parent_model}
          self.table_name = 'devices'

          belongs_to :user
          has_many :events

          def self.random
            new(
              name: SecureRandom.hex,
              user_id: User.order('random()').first&.id,
              created_at: rand(180_000...360_000).hours.ago
            )
          end
        end

        class Event < #{@parent_model}
          ACTIONS = %i[create update destroy].freeze

          self.table_name = 'events'

          belongs_to :device
          has_one :user, through: :device

          def self.random
            new(
              value: rand,
              action: ACTIONS.sample,
              image_data: { foo: 'bar' },
              device_id: Device.order('random()').first&.id,
              created_at: rand(0...180_000).hours.ago
            )
          end
        end

        model :user, User
        model :device, Device
        model :event, Event
      RUBY
    end

    def self.parent_model
      @parent_model
    end

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

    def ten_thousand_random_inserts
      10_000.times { event_model.random.save! }
    end

    def ten_thousand_sequential_ascending_inserts
      10_000.times do |i|
        event_model.random.tap { |r| r.created_at = i.minutes.from_now }.save!
      end
    end

    def ten_thousand_sequential_descending_inserts
      10_000.times do |i|
        event_model.random.tap { |r| r.created_at = i.minutes.ago }.save!
      end
    end

    def parallel_simple_reads_and_random_writes_with_min_records
      parallel_simple_reads_and_random_writes
    end

    def parallel_simple_reads_and_random_writes_with_max_records
      parallel_simple_reads_and_random_writes
    end

    def parallel_simple_reads_and_random_writes
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

    def parallel_complex_reads_and_random_writes_with_min_records
      parallel_complex_reads_and_random_writes
    end

    def parallel_complex_reads_and_random_writes_with_max_records
      parallel_complex_reads_and_random_writes
    end

    def parallel_complex_reads_and_random_writes
      writers = TsTest.config.fetch(:parallel_writers).times.map do
        Thread.new do
          10_000.times { event_model.random.save! }
        end
      end

      readers = TsTest.config.fetch(:parallel_readers).times.map do
        Thread.new do
          10_000.times do
            event_model
              .select('SUM(events.value), '\
                      'EXTRACT(year FROM events.created_at), '\
                      'COUNT(devices.id), COUNT(users.id)')
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

    def execute(sql)
      parent_model.connection.execute(sql)
    end

    def parent_model
      self.class.parent_model ||
        raise("No parent model defined for runner #{self.class}")
    end

    def event_model
      self.class.model(:event) ||
        raise("#{self.class} didn't specify an Event model using `model :event, Event`")
    end
  end
end
