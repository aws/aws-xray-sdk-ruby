require 'active_record'

module XRay
  module Rails
    # Recording Rails database transactions as subsegments.
    module ActiveRecord
      class << self
        IGNORE_OPS = ['SCHEMA', 'ActiveRecord::SchemaMigration Load',
                      'ActiveRecord::InternalMetadata Load'].freeze
        DB_TYPE_MAPPING = {
          mysql2: 'MySQL',
          postgresql: 'PostgreSQL'
        }.freeze

        def record(transaction)
          payload = transaction.payload
          pool, conn = get_pool_n_conn(payload[:connection].object_id)

          return if IGNORE_OPS.include?(payload[:name]) || pool.nil? || conn.nil?
          # The spec notation is Rails < 6.1, later this can be found in the db_config
          db_config = if pool.respond_to?(:spec)
                        pool.spec.config
                      else
                        pool.db_config.configuration_hash
                      end
          name, sql = build_name_sql_meta config: db_config, conn: conn
          sql[:sanitized_query] = payload[:sql]
          subsegment = XRay.recorder.begin_subsegment name, namespace: 'remote'
          # subsegment is nil in case of context missing
          return if subsegment.nil?
          # Rails 7.1 introduced time measurement in milliseconds instead seconds of causing xray-sdk to report wrong duration for transaction calls.
          # This is being handled in rails 7.2 and later. https://github.com/rails/rails/pull/50779 
          subsegment.start_time = (::Rails::VERSION::MAJOR == 7 and ::Rails::VERSION::MINOR == 1) ? transaction.time.to_f/1000 : transaction.time.to_f
          subsegment.sql = sql
          XRay.recorder.end_subsegment end_time: (::Rails::VERSION::MAJOR == 7 and ::Rails::VERSION::MINOR == 1) ? transaction.end.to_f/1000 : transaction.end.to_f
        end

        private

        def build_name_sql_meta(config:, conn:)
          # extract all available info
          adapter = config[:adapter]
          database = config[:database]
          host = config[:host].nil? ? nil : %(@#{config[:host]})
          port = config[:port].nil? ? nil : %(:#{config[:port]})
          username = config[:username]

          # assemble subsegment name
          name = %(#{database}#{host})
          # assemble sql meta
          sql = {}
          sql[:user] = username
          sql[:url] = %(#{adapter}://#{username}#{host}#{port}/#{database})
          sql[:database_type] = DB_TYPE_MAPPING[adapter.to_sym]
          [name, sql]
        end

        def get_pool_n_conn(conn_id)
          pool, conn = nil, nil
          ::ActiveRecord::Base.connection_handler.connection_pool_list.each do |p|
            conn = p.connections.select { |c| c.object_id == conn_id }
            pool = p unless conn.nil?
            return [pool, conn] if !conn.nil? && !conn.empty? && !pool.nil?
          end
          [pool, conn]
        end
      end
    end
  end
end

# Add a hook on database transactions using Rails instrumentation API
ActiveSupport::Notifications.subscribe('sql.active_record') do |*args|
  # We need the full event which has all the timing info
  transaction = ActiveSupport::Notifications::Event.new(*args)
  XRay::Rails::ActiveRecord.record(transaction)
end
