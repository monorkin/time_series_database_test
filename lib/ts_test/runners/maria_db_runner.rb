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

      build_models_for MariaDbRecord

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
    end
  end
end
