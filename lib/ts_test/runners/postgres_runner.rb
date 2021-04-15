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

        insert_users!(TsTest.config.fetch(:user_count))
        insert_devices!(TsTest.config.fetch(:device_count))
        insert_events!(TsTest.config.fetch(:event_count))
      end

      def teardown!
        drop_tables!
      end

      def drop_tables!
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
                   NOW()  +  (i * interval '1 second')
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
                   NOW() +   (i * interval '1 second')
            FROM generate_series(1, #{count}) s(i)
          SQL
        )
      end

      def insert_users!(count)
        execute(
          <<~SQL
            INSERT INTO users (name, created_at)
            SELECT MD5(random()::text),
                   NOW() +  (i * interval '1 second')
            FROM generate_series(1, #{count}) s(i)
          SQL
        )
      end
    end
  end
end
