require_relative '../spec_helper'
require 'timecop'
require 'daemons'
require '3scale/backend/worker_async'

module ThreeScale
  module Backend
    context 'when there are jobs enqueued' do
      # For these tests, we are going to perform a number of reports, and then,
      # verify that the stats usage keys have been updated correctly.

      let(:provider_key) { 'a_provider_key' }
      let(:service_id) { 'a_service_id' }
      let(:app_id) { 'an_app_id' }
      let(:metric_id) { 'a_metric_id' }
      let(:metric_name) { 'hits' }

      let(:current_time) { Time.now }

      let(:stats_key) do # Using daily key, but could be any other
        Stats::Keys.application_usage_value_key(
          service_id, app_id, metric_id, Period[:day].new(current_time)
        )
      end

      let(:n_reports) { 10 }
      let(:process_jobs_timeout_secs) { 5 }

      before do
        Service.save!(provider_key: provider_key, id: service_id)

        Application.save(service_id: service_id,
                         id: app_id,
                         state: :active)

        Metric.save(service_id: service_id,
                    id: metric_id,
                    name: metric_name)

        report_jobs(n_reports, current_time, provider_key, service_id, app_id, metric_name, 1)
      end

      it 'processes them' do
        worker = Worker.new(async: true, job_fetcher: JobFetcher.new(fetch_timeout: 1))

        process_jobs(worker, n_reports, process_jobs_timeout_secs)

        expect(Storage.instance.get(stats_key).to_i).to eq n_reports
      end

      context 'when there is a connection issue while trying to fetch jobs from the queue' do
        let(:test_redis) { double }

        before do
          allow(test_redis).to receive(:blpop).and_raise(Errno::EPIPE)
          allow(Backend.logger).to receive(:notify) # suppress errors in output
        end

        it 'recovers and continues processing jobs' do
          # 'test_redis' will only be used once, after it raises, the worker
          # will create a non-mocked instance of the client
          worker = Worker.new(
            async: true,
            job_fetcher: JobFetcher.new(fetch_timeout: 1, redis_client: test_redis)
          )

          process_jobs(worker, n_reports, process_jobs_timeout_secs)

          expect(Storage.instance.get(stats_key).to_i).to eq n_reports
        end
      end

      def report_jobs(n_jobs, current_time, provider_key, service_id, app_id, metric_name, value)
        without_resque_spec do
          Timecop.freeze(current_time) do
            n_jobs.times do
              Transactor.report(
                provider_key,
                service_id,
                0 => { app_id: app_id, usage: { metric_name => value } }
              )
            end
          end
        end
      end

      def process_jobs(worker, n_jobs, timeout_seconds)
        worker_thread = Thread.new { worker.work }

        # We do not know when the worker thread will finish processing all the
        # jobs. If it takes too much, we will assume that there has been some
        # kind of error.
        t_start = Time.now

        while Storage.instance.get(stats_key).to_i < n_jobs
          if Time.now - t_start > timeout_seconds
            raise 'The worker is taking too much to process the jobs'
          end

          sleep(0.1)
        end

        ensure
          worker.shutdown
          worker_thread.join
      end
    end
  end
end
