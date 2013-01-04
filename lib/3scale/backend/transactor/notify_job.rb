module ThreeScale
  module Backend
    module Transactor
      # Job for notifying about backend calls. 
      class NotifyJob
        extend Configurable

        @queue = :main

        def self.perform(provider_key, usage, timestamp, enqueue_time)
          start_time = Time.now.getutc
          
          application_id = Application.load_id_by_key(master_service_id, provider_key)

          if application_id && Application.exists?(master_service_id, application_id)
            master_metrics = Metric.load_all(master_service_id)

            ProcessJob.perform([{:service_id     => master_service_id,
                                 :application_id => application_id,
                                 :timestamp      => timestamp,
                                 :usage          => master_metrics.process_usage(usage)}], :master => true)
          end
          
          stats_mem = Memoizer.stats
          end_time = Time.now.getutc
          Worker.logger.info("NotifyJob #{provider_key} #{application_id || "--"} #{(end_time-start_time).round(5)} #{(end_time.to_f-enqueue_time).round(5)} #{stats_mem[:size]} #{stats_mem[:count]} #{stats_mem[:hits]}")
        end

        def self.master_service_id
          value = configuration.master_service_id
          value ? value.to_s : raise("Can't find master service id. Make sure the \"master_service_id\" configuration value is set correctly")
        end
      end
    end
  end
end
