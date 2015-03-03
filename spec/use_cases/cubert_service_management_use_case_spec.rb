require_relative '../spec_helper'

module ThreeScale
  module Backend
    describe CubertServiceManagementUseCase do
      let(:storage) { ThreeScale::Backend::Storage.instance }
      let(:use_case){ CubertServiceManagementUseCase }
      let(:enabled_service) { use_case.new('7001').enable_service; '7001' }
      let(:disabled_service) { '7002' }

      describe '.disable_service' do
        before { use_case.new(enabled_service).disable_service }

        it 'remove the cubert bucket info from Redis' do
          expect(use_case.new(enabled_service).bucket).to be_nil
        end

        it 'removes the service from the list of enabled services' do
          expect(storage.smembers(use_case.enabled_services_key)).to be_empty
        end
      end

      describe '.clean_cubert_redis_keys' do
        before do
          use_case.global_enable
          enabled_service
          use_case.clean_cubert_redis_keys
        end

        it 'removes all the keys' do
          expect(storage.get use_case.global_lock_key).to be_nil
          expect(storage.smembers use_case.enabled_services_key).to be_empty
          expect(use_case.new(enabled_service).bucket).to be_nil
        end
      end

    end
  end
end

