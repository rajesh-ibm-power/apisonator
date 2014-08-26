module ThreeScale
  module Backend
    class UsageLimit < Core::UsageLimit
      include Memoizer::Decorator

      def validate(usage)
        usage_value = usage[period]
        usage_value &&= usage_value[metric_id].to_i
        usage_value <= value
      end

      ## memoize loading the usage limits of the plan
      def self.load_all(service_id, plan_id)
        super(service_id, plan_id)
      end
      memoize :load_all

    end
  end
end
