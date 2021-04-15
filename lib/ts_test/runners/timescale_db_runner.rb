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
            ALTER TABLE events DROP CONSTRAINT events_pkey;
          SQL
        )

        execute(
          <<~SQL
            ALTER TABLE events ADD PRIMARY KEY (id, created_at);
          SQL
        )

        execute(
          <<~SQL
            SELECT create_hypertable('events', 'created_at');
          SQL
        )
      end
    end
  end
end
