require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe LogRequestCubertStorage do
      let(:storage) { ThreeScale::Backend::Storage.instance }
      let(:enabled_service) do
        bucket_id = Cubert::Client::Connection.new('http://localhost:8080').
          create_bucket
        storage.set(LogRequestCubertStorage.send(:bucket_id_key, '7001'), bucket_id)
        '7001'
      end
      let(:disabled_service) { '7002' }

      describe '.store' do
        let(:enabled_service_log) { example_log(service_id: enabled_service) }
        let(:disabled_service_log) { example_log(service_id: disabled_service) }

        it 'runs when the service usage flag is enabled' do
          doc_id = LogRequestCubertStorage.store(enabled_service_log)

          expect(LogRequestCubertStorage.get(enabled_service, doc_id).
            body['service_id']).to eq(enabled_service_log[:service_id])
        end

        it "doesn't run when the service usage flag is disabled" do
          doc_id = LogRequestCubertStorage.store(disabled_service_log)

          expect(doc_id).to be_nil
        end
      end

      describe 'service related methods' do
        let(:other_service) { '7003' }

        describe '.list_by_service' do
          let(:results) do
            LogRequestCubertStorage.store_all [
              example_log(service_id: enabled_service, log: 'foo'),
              example_log(service_id: other_service, log: 'baz'),
              example_log(service_id: enabled_service, log: 'bar')
            ]
            LogRequestCubertStorage.list_by_service(enabled_service)
          end

          it 'lists all logs' do
            expect(results.any? { |el| el['log'] == 'foo' }).to be_true
            expect(results.any? { |el| el['log'] == 'bar' }).to be_true
          end

          it 'lists logs just from the queried service' do
            expect(results.any? { |el| el['log'] == 'baz' }).to be_false
          end
        end

        describe '.count_by_service' do
          let(:results) do
            LogRequestCubertStorage.store_all [
              example_log(service_id: enabled_service, log: 'foo'),
              example_log(service_id: other_service, log: 'baz'),
              example_log(service_id: enabled_service, log: 'bar')
            ]
            LogRequestCubertStorage.count_by_service(enabled_service)
          end

          it 'lists all logs' do
            expect(results).to eq(2)
          end

        end
      end

      describe 'application related methods' do
        let(:app){ '1001' }
        let(:other_app){ '1002' }

        describe '.list_by_application' do
          let(:results) do
            LogRequestCubertStorage.store_all [
              example_log(service_id: enabled_service, log: 'foo',
                application_id: app),
              example_log(service_id: enabled_service, log: 'baz',
                application_id: other_app),
              example_log(service_id: enabled_service, log: 'bar',
                application_id: app)
            ]
            LogRequestCubertStorage.list_by_application(enabled_service, app)
          end

          it 'lists all logs' do
            expect(results.any? { |el| el['log'] == 'foo' }).to be_true
            expect(results.any? { |el| el['log'] == 'bar' }).to be_true
          end

          it 'lists logs just from the queried service' do
            expect(results.any? { |el| el['log'] == 'baz' }).to be_false
          end
        end

        describe '.count_by_application' do
          let(:results) do
            LogRequestCubertStorage.store_all [
              example_log(service_id: enabled_service, log: 'foo',
                application_id: app),
              example_log(service_id: enabled_service, log: 'baz',
                application_id: other_app),
              example_log(service_id: enabled_service, log: 'bar',
                application_id: app)
            ]
            LogRequestCubertStorage.count_by_application(enabled_service, app)
          end

          it 'returns the count of request logs' do
            expect(results).to eq(2)
          end
        end
      end

      private

      def example_log(params = {})
        default_params = {
          service_id: 1,
          application_id: 2,
          usage: {"metric_id_one" => 1},
          timestamp: Time.utc(2010, 9, 10, 17, 4),
          log: {'request' => 'req', 'response' => 'resp', 'code' => 200}
        }
        default_params.merge params
      end

    end
  end
end


