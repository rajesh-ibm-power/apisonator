require_relative '../../spec_helper'
require_relative '../../../lib/3scale/backend/stats/kinesis_adapter'

module ThreeScale
  module Backend
    module Stats
      describe KinesisAdapter do
        let(:kinesis_client) { double }
        let(:stream_name) { 'backend_stream' }
        let(:events_per_record) { described_class.const_get(:EVENTS_PER_RECORD) }
        let(:max_records_per_batch) { described_class.const_get(:MAX_RECORDS_PER_BATCH) }
        let(:event) { { service: 's', metric: 'm', period: 'year', year: '2015' } }

        subject { described_class.new(stream_name, kinesis_client) }

        describe '#send_events' do
          context 'the number of events is smaller than the number of events per record' do
            let(:events) { Array.new(events_per_record - 1, event) }

            before { expect(kinesis_client).not_to receive(:put_record_batch) }

            it 'does not send the events to Kinesis' do
              subject.send_events(events)
            end

            it 'adds the events to the array of pending events' do
              subject.send_events(events)
              expect(subject.send(:pending_events)).to eq events
            end
          end

          context 'the number of events is enough to fill a record and can be send in 1 batch' do
            let(:events) { Array.new(events_per_record, event) }

            before do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: [{ data: events.to_json }] })
            end

            it 'sends the events to Kinesis' do
              subject.send_events(events)
            end

            it 'pending events is empty' do
              subject.send_events(events)
              expect(subject.send(:pending_events)).to be_empty
            end
          end

          context 'the number of events fills several records but can be send in 1 batch' do
            let(:records) { 2 } # Assuming that a batch can contain at least 2 records
            let(:events) { Array.new(records*events_per_record, event) }
            let(:kinesis_records) do
              Array.new(records, { data: Array.new(events_per_record, event).to_json })
            end

            before do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: kinesis_records })
            end

            it 'sends the events to Kinesis' do
              subject.send_events(events)
            end

            it 'pending events is empty' do
              subject.send_events(events)
              expect(subject.send(:pending_events)).to be_empty
            end
          end

          context 'the number of events is too big to be sent in just one batch' do
            let(:records) { max_records_per_batch + 1 }
            let(:events) { Array.new(records*events_per_record, event) }
            let(:kinesis_records) do
              Array.new(max_records_per_batch,
                        { data: Array.new(events_per_record, event).to_json })
            end

            before do
              expect(kinesis_client)
                  .to receive(:put_record_batch)
                          .with({ delivery_stream_name: stream_name,
                                  records: kinesis_records })
            end

            it 'sends a batch to Kinesis' do
              subject.send_events(events)
            end

            it 'pending events includes the events that did not fit in the batch' do
              subject.send_events(events)
              expect(subject.send(:pending_events)).to eq Array.new(events_per_record, event)
            end
          end
        end
      end
    end
  end
end
