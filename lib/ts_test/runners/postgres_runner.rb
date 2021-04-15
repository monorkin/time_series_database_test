# frozen_string_literal: true

require 'pg'
require 'securerandom'

module TsTest
  module Runners
    class PostgresRunner < Runner
      class PostgresRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      PostgresRecord.establish_connection(
        TsTest.config.dig(:databases, :postgres)
      )

      class User < PostgresRecord
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

      class Device < PostgresRecord
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

      class Event < PostgresRecord
        ACTION = %i[create update destroy].freeze

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

      def prepare!
        drop_tables!

        event_model.connection.execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS users (
              id SERIAL PRIMARY KEY,
              name VARCHAR(255),
              created_at TIMESTAMP
            );
          SQL
        )
        event_model.connection.execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS devices (
              id SERIAL PRIMARY KEY,
              name VARCHAR(255),
              user_id INT8,
              created_at TIMESTAMP
            );
          SQL
        )
        event_model.connection.execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS events (
              id SERIAL PRIMARY KEY,
              value FLOAT,
              action VARCHAR(255),
              image_data JSONB,
              device_id INT8,
              created_at TIMESTAMP
            );
          SQL
        )
      end

      def teardown!
        #drop_tables!
      end

      def drop_tables!
        return
        event_model.connection.execute(
          <<~SQL
            DROP TABLE IF EXISTS events;
          SQL
        )
        event_model.connection.execute(
          <<~SQL
            DROP TABLE IF EXISTS devices;
          SQL
        )
        event_model.connection.execute(
          <<~SQL
            DROP TABLE IF EXISTS users;
          SQL
        )
      end

      def insert_events!(count)
        event_model.connection.execute(
          <<~SQL
            INSERT INTO events (value, action, image_data, device_id, created_at)
            SELECT random()::float,
                   random()::text,
                   '{"foo": "bar"}',
                   (SELECT id FROM devices ORDER BY random() LIMIT 1),
                   NOW()  +  (i * interval '1 minute')
            FROM generate_series(1, #{count}) s(i)
          SQL
        )
      end

      def insert_devices!(count)
        event_model.connection.execute(
          <<~SQL
            INSERT INTO devices (name, user_id, created_at)
            SELECT MD5(random()::text),
                   (SELECT id FROM users ORDER BY random() LIMIT 1),
                   NOW() +  +  (i * interval '1 minute')
            FROM generate_series(1, #{count}) s(i)
          SQL
        )
      end

      def insert_users!(count)
        event_model.connection.execute(
          <<~SQL
            INSERT INTO users (name, created_at)
            SELECT MD5(random()::text),
                   NOW() +   (i * interval '1 minute')
            FROM generate_series(1, #{count}) s(i)
          SQL
        )
      end

      def truncate_tables!
        return
        event_model.connection.execute('TRUNCATE TABLE events')
        event_model.connection.execute('TRUNCATE TABLE devices')
        event_model.connection.execute('TRUNCATE TABLE users')
      end

      def ten_thousand_random_inserts_prepare!
        truncate_tables!
        insert_users!(3)
        insert_devices!(3)
      end

      def ten_thousand_random_inserts_teardown!
        truncate_tables!
      end

      def ten_thousand_sequential_ascending_inserts_prepare!
        truncate_tables!
        insert_users!(3)
        insert_devices!(3)
      end

      def ten_thousand_sequential_ascending_inserts_teardown!
        truncate_tables!
      end

      def ten_thousand_sequential_descending_inserts_prepare!
        truncate_tables!
        insert_users!(3)
        insert_devices!(3)
      end

      def ten_thousand_sequential_descending_inserts_teardown!
        truncate_tables!
      end

      def parallel_simple_reads_and_random_writes_with_min_records_prepare!
        print ' - P'
        start = Time.now.to_i
        truncate_tables!
        insert_users!(3)
        insert_devices!(3)
        insert_events!(TsTest.config.fetch(:min_records_in_table))
        finish = Time.now.to_i
        print "(#{finish - start}s)"
      end

      def parallel_simple_reads_and_random_writes_with_min_records_teardown!
        truncate_tables!
      end

      def parallel_simple_reads_and_random_writes_with_max_records_prepare!
        print ' - P'
        start = Time.now.to_i
        truncate_tables!
        insert_users!(3)
        insert_devices!(3)
        insert_events!(TsTest.config.fetch(:max_records_in_table))
        finish = Time.now.to_i
        print "(#{finish - start}s)"
      end

      def parallel_simple_reads_and_random_writes_with_max_records_teardown!
        truncate_tables!
      end

      def parallel_complex_reads_and_random_writes_with_min_records_prepare!
        print ' - P'
        start = Time.now.to_i
        truncate_tables!
        insert_users!(10_000)
        insert_devices!(20_000)
        insert_events!(TsTest.config.fetch(:min_records_in_table))
        finish = Time.now.to_i
        print "(#{finish - start}s)"
      end

      def parallel_complex_reads_and_sequential_writes_with_min_records_prepare!
        parallel_complex_reads_and_random_writes_with_min_records_prepare!
      end

      def parallel_complex_reads_and_random_writes_with_min_records_teardown!
        truncate_tables!
      end

      def parallel_complex_reads_and_random_writes_with_max_records_prepare!
        print ' - P'
        start = Time.now.to_i
        truncate_tables!
        insert_users!(10_000)
        insert_devices!(20_000)
        insert_events!(TsTest.config.fetch(:max_records_in_table))
        finish = Time.now.to_i
        print "(#{finish - start}s)"
      end

      def parallel_complex_reads_and_random_writes_with_max_records_teardown!
        truncate_tables!
      end
    end
  end
end
