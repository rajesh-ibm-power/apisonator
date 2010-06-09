require File.dirname(__FILE__) + '/../../test_helper'

module Serializers
  class StatusV1_0Test < Test::Unit::TestCase
    include TestHelpers::EventMachine

    def setup
      Storage.instance(true).flushdb
      
      @service_id  = 1001
      @plan_id     = 2001
      @contract_id = 3001
      @metric_id   = 4001

      @contract = Contract.new(:service_id => @service_id,
                               :id         => @contract_id,
                               :plan_id    => @plan_id,
                               :plan_name  => 'awesome')

      Metric.save(:service_id => @service_id, :id => @metric_id, :name => 'foos')
    end

    def test_serialize
      UsageLimit.save(:service_id => @service_id,
                      :plan_id    => @plan_id,
                      :metric_id  => @metric_id,
                      :month      => 2000)

      time = Time.utc(2010, 5, 17, 12, 42)
      usage = {:month => {@metric_id.to_s => 429}}

      Timecop.freeze(time) do
        status = Transactor::Status.new(@contract, usage)
        xml    = Serializers::StatusV1_0.serialize(status)
        doc    = Nokogiri::XML(xml)
        
        root = doc.at('status:root')        
        assert_not_nil doc.at('status:root')
        assert_equal 'awesome', root.at('plan').content

        usage = root.at('usage[metric = "foos"][period = "month"]')
        assert_not_nil usage
        assert_equal '2010-05-01 00:00:00', usage.at('period_start').content
        assert_equal '2010-06-01 00:00:00', usage.at('period_end').content
        assert_equal '429', usage.at('current_value').content
        assert_equal '2000', usage.at('max_value').content
      end
    end

    def test_serialize_rejected_status
      status = Transactor::Status.new(@contract, {})
      status.reject!('user.inactive_contract')

      xml = Serializers::StatusV1_0.serialize(status)      
      doc = Nokogiri::XML(xml)

      root = doc.at('errors:root')
      assert_not_nil root

      assert_equal 1, root.search('error').count
      error = root.at('error')

      assert_equal 'user.inactive_contract', error['code']
      assert_equal 'contract is not active', error.content
    end
  end
end
