# frozen_string_literal: true

require 'pg'
require 'securerandom'

module TsTest
  module Runners
    class TimescaleDbRunner < PostgresRunner
      class TimescaleDbRecord < ActiveRecord::Base
        self.abstract_class = true
      end

      TimescaleDbRecord.establish_connection(
        TsTest.config.dig(:databases, :timescale_db)
      )

      build_models_for TimescaleDbRecord

      def prepare!
        execute(
          <<~SQL
            CREATE EXTENSION IF NOT EXISTS timescaledb;
          SQL
        )

        super

        execute(
          <<~SQL
            ALTER TABLE events DROP CONSTRAINT IF EXISTS events_pkey;
          SQL
        )

        execute(
          <<~SQL
            SELECT create_hypertable('events',
                                     'created_at',
                                     if_not_exists => true,
                                     migrate_data => true);
          SQL
        )
      end
    end
  end
end
