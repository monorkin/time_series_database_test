# frozen_string_literal: true

require 'pg'

module TsTest
  module Runners
    class PostgresRunner < Runner
      class PostgresRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      PostgresRecord.establish_connection(
        TsTest.config.dig(:databases, :postgres)
      )

      build_models_for PostgresRecord

      def prepare!
        drop_tables!

        execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS users (
              id SERIAL PRIMARY KEY,
              name VARCHAR(255),
              created_at TIMESTAMP
            );
          SQL
        )
        execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS devices (
              id SERIAL PRIMARY KEY,
              name VARCHAR(255),
              user_id INT8,
              created_at TIMESTAMP
            );
          SQL
        )
        execute(
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
        execute(
          <<~SQL
            DROP TABLE IF EXISTS events;
          SQL
        )
        execute(
          <<~SQL
            DROP TABLE IF EXISTS devices;
          SQL
        )
        execute(
          <<~SQL
            DROP TABLE IF EXISTS users;
          SQL
        )
      end

      def insert_events!(count)
        execute(
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
        execute(
          <<~SQL
            INSERT INTO devices (name, user_id, created_at)
            SELECT MD5(random()::text),
                   (SELECT id FROM users ORDER BY random() LIMIT 1),
                   NOW() +   (i * interval '1 minute')
            FROM generate_series(1, #{count}) s(i)
          SQL
        )
      end

      def insert_users!(count)
        execute(
          <<~SQL
            INSERT INTO users (name, created_at)
            SELECT MD5(random()::text),
                   NOW() +  (i * interval '1 minute')
            FROM generate_series(1, #{count}) s(i)
          SQL
        )
      end

      def truncate_tables!
        return
        execute('TRUNCATE TABLE events')
        execute('TRUNCATE TABLE devices')
        execute('TRUNCATE TABLE users')
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
