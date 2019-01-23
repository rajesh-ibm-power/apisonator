module ThreeScale
  module Backend
    module Stats
      module Commons
        SERVICE_GRANULARITIES = %i[eternity month week day hour].map do |g|
          Period[g]
        end.freeze

        # For applications and users
        EXPANDED_GRANULARITIES = (SERVICE_GRANULARITIES + [Period[:year], Period[:minute]]).freeze

        GRANULARITY_EXPIRATION_TIME = { Period[:minute] => 180 }.freeze
        private_constant :GRANULARITY_EXPIRATION_TIME

        PERMANENT_SERVICE_GRANULARITIES = (SERVICE_GRANULARITIES - GRANULARITY_EXPIRATION_TIME.keys).freeze
        PERMANENT_EXPANDED_GRANULARITIES = (EXPANDED_GRANULARITIES - GRANULARITY_EXPIRATION_TIME.keys).freeze

        # We are not going to send metrics with granularity 'eternity' or
        # 'week' to Kinesis, so there is no point in storing them in Redis
        # buckets.
        EXCLUDED_FOR_BUCKETS = [Period[:eternity], Period[:week]].freeze

        # Return an array of granularities given a metric_type
        def self.granularities(metric_type)
          metric_type == :service ? SERVICE_GRANULARITIES : EXPANDED_GRANULARITIES
        end

        def self.expire_time_for_granularity(granularity)
          GRANULARITY_EXPIRATION_TIME[granularity]
        end

        TRACKED_CODES = [200, 404, 403, 500, 503].freeze
        HTTP_CODE_GROUPS_MAP = Hash[1.upto(9).map { |i| [i, "#{i}XX"] }]

        def self.get_http_code_group(http_code)
          HTTP_CODE_GROUPS_MAP.fetch(http_code / 100)
        end
      end
    end
  end
end
