# frozen_string_literal: true

require 'click_house'
require 'clickhouse-activerecord'

module TsTest
  module Runners
    class ClickHouseRunner < Runner
      class ClickHouseRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      execute(
        TsTest.config.dig(:databases, :click_house),
        'CREATE DATABASE IF NOT EXISTS test;'
      )

      ClickHouseRecord.establish_connection(
        TsTest.config.dig(:databases, :click_house)
      )

      build_models_for ClickHouseRecord, random_function: 'RAND()'

      def prepare!
        drop_tables!

        puts 'Creating users table' if verbose?

        execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS users (
              id SERIAL PRIMARY KEY,
              name VARCHAR(255),
              created_at TIMESTAMP
            );
          SQL
        )

        puts 'Creating devices table' if verbose?

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

        puts 'Creating events table' if verbose?

        execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS events (
              id SERIAL PRIMARY KEY,
              value FLOAT64,
              action STRING,
              image_data STRING,
              device_id UINT8,
              created_at TIMESTAMP
            );
          SQL
        )

        puts 'Creating users' if verbose?
        insert_users!(TsTest.config.fetch(:user_count))

        puts 'Creating devices' if verbose?
        insert_devices!(TsTest.config.fetch(:device_count))

        puts 'Creating events' if verbose?
        insert_events!(TsTest.config.fetch(:event_count))
      end

      def teardown!
        drop_tables!
      end

      def drop_tables!
        puts 'Dropping events table' if verbose?

        execute(
          <<~SQL
            DROP TABLE IF EXISTS events;
          SQL
        )

        puts 'Dropping devices table' if verbose?

        execute(
          <<~SQL
            DROP TABLE IF EXISTS devices;
          SQL
        )

        puts 'Dropping users table' if verbose?

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
