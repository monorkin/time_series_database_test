# frozen_string_literal: true

require 'benchmark'
require 'securerandom'
require 'uri'

module TsTest
  class Runner
    DEFUALT_MODEL_OPTIONS = { random_function: 'random()' }.freeze

    attr_reader :options
    attr_reader :results

    delegate :drop_table,
             :create_table,
             :table_exists?,
             :add_index,
             :remove_index,
             :execute,
             to: :connection

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

    def self.build_models_for(parent_model_class, options = {})
      options = DEFUALT_MODEL_OPTIONS.merge(options)
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
              user_id: User.order('#{options[:random_function]}').first&.id,
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
              device_id: Device.order('#{options[:random_function]}').first&.id,
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

    def parallel_complex_reads_and_sequential_writes
      writers = TsTest.config.fetch(:parallel_writers).times.map do
        Thread.new do
          10_000.times do |i|
            event_model.random.tap { |r| r.created_at = i.minutes.ago }.save!
          end
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

    def run(case_name)
      puts "Testing #{self.class}##{case_name}" if verbose?

      unless respond_to?(case_name)
        raise(NotImplementedError,
              "#{self.class} doesn't implement test case #{case_name}")
      end

      results[case_name] ||= []

      start = Time.now.to_i

      begin
        if prepare?
          puts 'Preparing DB' if verbose?
          prep = Benchmark.measure { call_if_responds_to(:prepare!) }
          puts "Took: #{prep.total}s" if verbose?
        end

        puts 'Preparing test...' if verbose?
        call_if_responds_to("#{case_name}_prepare!".to_sym)

        puts 'Benchmarking...' if verbose?
        results[case_name] << Benchmark.measure(case_name) { public_send(case_name) }
      ensure
        puts 'Tearing down test...' if verbose?
        call_if_responds_to("#{case_name}_teardown!".to_sym)

        if teardown?
          puts 'Tearing down DB' if verbose?
          prep = Benchmark.measure { call_if_responds_to(:teardown!) }
          puts "Took: #{prep.total}s" if verbose?
        end
      end

      finish = Time.now.to_i

      if verbose?
        puts "Test took #{finish - start}s to prepare, test and teardown"
      end

      true
    end

    def prepare!
      unless table_exists?('users')
        puts 'Creating users table' if verbose?
        create_users_table!
      end

      unless table_exists?('devices')
        puts 'Creating devices table' if verbose?
        create_devices_table!
      end

      unless table_exists?('events')
        puts 'Creating events table' if verbose?
        create_events_table!
      end

      desired_count = TsTest.config.fetch(:user_count)
      current_count = user_model.count
      delta = desired_count - current_count
      if delta.positive?
        puts "Creating #{delta} users" if verbose?
        insert_users!(delta, current_count + 1)
      end

      desired_count = TsTest.config.fetch(:device_count)
      current_count = device_model.count
      delta = desired_count - current_count
      if delta.positive?
        puts "Creating #{delta} devices" if verbose?
        insert_devices!(delta, current_count + 1)
      end

      desired_count = TsTest.config.fetch(:event_count)
      current_count = event_model.count
      delta = desired_count - current_count
      if delta.positive?
        puts "Creating #{delta} events" if verbose?
        insert_events!(delta, current_count + 1)
      end
    end

    def create_users_table!
      create_table :users do |t|
        t.string :name
        t.datetime :created_at
      end
    end

    def create_devices_table!
      create_table :devices do |t|
        t.string :name
        t.foreign_key :user_id
        t.datetime :created_at
      end
    end

    def create_events_table!
      create_table :events do |t|
        t.float :value
        t.string :action
        t.string :image_data
        t.foreign_key :device_id
        t.datetime :created_at
      end
    end

    def insert_events!(count, starting_at = 0)
      count.times do |i|
        event_model.random.tap do |r|
          r.id = starting_at + i
          r.created_at = i.seconds.from_now
        end.save!
      end
    end

    def insert_devices!(count, starting_at = 0)
      count.times do |i|
        device_model.random.tap do |r|
          r.id = starting_at + i
          r.created_at = i.seconds.from_now
        end.save!
      end
    end

    def insert_users!(count, starting_at = 0)
      count.times do |i|
        user_model.random.tap do |r|
          r.id = starting_at + i
          r.created_at = i.seconds.from_now
        end.save!
      end
    end

    def teardown!
      drop_tables!
    end

    def drop_tables!
      if table_exists?('events')
        puts 'Dropping events table' if verbose?
        drop_table('events')
      end

      if table_exists?('devices')
        puts 'Dropping devices table' if verbose?
        drop_table('devices')
      end

      if table_exists?('users')
        puts 'Dropping users table' if verbose?
        drop_table('users')
      end
    end

    private

    def call_if_responds_to(method_name)
      return false unless respond_to?(method_name)

      puts "Executing #{self.class}##{method_name}" if verbose?
      public_send(method_name)
    end

    def verbose?
      !!options[:verbose]
    end

    def prepare?
      !!options[:prepare]
    end

    def teardown?
      !!options[:teardown]
    end

    def connection
      parent_model.connection
    end

    def parent_model
      self.class.parent_model ||
        raise("No parent model defined for runner #{self.class}")
    end

    def user_model
      self.class.model(:user) ||
        raise("#{self.class} didn't specify a User model using `model :user, User`")
    end

    def device_model
      self.class.model(:device) ||
        raise("#{self.class} didn't specify a Device model using `model :device, Device`")
    end

    def event_model
      self.class.model(:event) ||
        raise("#{self.class} didn't specify an Event model using `model :event, Event`")
    end
  end
end
