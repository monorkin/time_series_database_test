# frozen_string_literal: true

require 'mysql2'

module TsTest
  module Runners
    class MariaDbRunner < Runner
      class MariaDbRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      execute(
        TsTest.config.dig(:databases, :maria_db),
        'CREATE DATABASE IF NOT EXISTS test;'
      )

      MariaDbRecord.establish_connection(
        TsTest.config.dig(:databases, :maria_db)
      )

      build_models_for MariaDbRecord, random_function: 'RAND()'

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
              image_data JSON,
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
        count.times do |i|
          execute(
            <<~SQL
              INSERT INTO events (value, action, image_data, device_id, created_at)
              VALUES (RAND(),
                     MD5(RAND()),
                     '{"foo": "bar"}',
                     (SELECT id FROM devices ORDER BY RAND() LIMIT 1),
                     TIMESTAMPADD(SECOND, #{i}, NOW()))
            SQL
          )
        end
      end

      def insert_devices!(count)
        count.times do |i|
          execute(
            <<~SQL
              INSERT INTO devices (name, user_id, created_at)
              VALUES (MD5(RAND()),
                     (SELECT id FROM users ORDER BY RAND() LIMIT 1),
                     TIMESTAMPADD(SECOND, #{i}, NOW()))
            SQL
          )
        end
      end

      def insert_users!(count)
        count.times do |i|
          execute(
            <<~SQL
              INSERT INTO users (name, created_at)
              VALUES (MD5(RAND()),
                     TIMESTAMPADD(SECOND, #{i}, NOW()))
            SQL
          )
        end
      end
    end
  end
end
