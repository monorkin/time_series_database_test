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

      class User < TimescaleDbRecord
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

      class Device < TimescaleDbRecord
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

      class Event < TimescaleDbRecord
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
        event_model.connection.execute(
          <<~SQL
            CREATE EXTENSION IF NOT EXISTS timescaledb;
          SQL
        )

        super

        event_model.connection.execute(
          <<~SQL
            ALTER TABLE events DROP CONSTRAINT events_pkey;
          SQL
        )

        event_model.connection.execute(
          <<~SQL
            SELECT create_hypertable('events', 'created_at', if_not_exists =>true);
          SQL
        )
      end
    end
  end
end
