# frozen_string_literal: true

require 'click_house'
require 'clickhouse-activerecord'

module TsTest
  module Runners
    class ClickHouseRunner < Runner
      class ClickHouseRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      ClickHouseRecord.establish_connection(
        TsTest.config.dig(:databases, :click_house)
      )

      build_models_for ClickHouseRecord, random_function: 'RAND()'

      def create_users_table!
        execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS users (
              id UInt64,
              name VARCHAR(255),
              created_at TIMESTAMP
            )
            ENGINE = MergeTree()
            PARTITION BY toYYYYMM(created_at)
            ORDER BY (created_at, intHash32(id))
            SAMPLE BY intHash32(id)
          SQL
        )
      end

      def create_devices_table!
        execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS devices (
              id UInt64,
              name VARCHAR(255),
              user_id UInt64,
              created_at TIMESTAMP
            )
            ENGINE = MergeTree()
            PARTITION BY toYYYYMM(created_at)
            ORDER BY (created_at, intHash32(user_id))
            SAMPLE BY intHash32(user_id)
          SQL
        )
      end

      def create_events_table!
        execute(
          <<~SQL
            CREATE TABLE IF NOT EXISTS events (
              id UInt64,
              value Float64,
              action String,
              image_data String,
              device_id UInt64,
              created_at TIMESTAMP
            )
            ENGINE = MergeTree()
            PARTITION BY toYYYYMM(created_at)
            ORDER BY (created_at, intHash32(device_id))
            SAMPLE BY intHash32(device_id)
          SQL
        )
      end
    end
  end
end
