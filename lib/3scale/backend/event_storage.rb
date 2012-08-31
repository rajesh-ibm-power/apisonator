
module ThreeScale
  module Backend
    module EventStorage
      include StorageHelpers
      extend self
      
      PING_TTL    = 60
      
      EVENT_TYPES = [:first_traffic, :alert]
      
      
      
      def store(type, object)
        raise Exception.new("Event type #{type} is invalid") unless EVENT_TYPES.member?(type)
        new_id = storage.incrby(events_id_key,1)
        event = {:id => new_id, :type => type, :timestamp => Time.now.utc, :object => object}
        storage.zadd(events_queue_key, event[:id], encode(event))
      end
        
      def list
        raw_items = storage.zrevrange(events_queue_key,0,-1)
        res = raw_items.map(&method(:decode)).reverse
        
        ## the decode does not symbolize keys and convert timestamps recursively...
        res.each do |item|
          item[:object] = item[:object].symbolize_keys if item[:object]
          item[:object][:timestamp] =  Time.parse_to_utc(item[:object][:timestamp]) if item[:object] && item[:object][:timestamp]
        end
        
        return res
      end

      def delete(to_id)
        storage.zremrangebyscore(events_queue_key,0,to_id)
      end
      
      def size
        storage.zcard(events_queue_key)
      end


      def ping_if_not_empty
        val = storage.pipelined do
          storage.zcard(events_queue_key)
          storage.get(events_ping_key)
          storage.set(events_ping_key)
          storage.expire(events_ping_key,PING_TTL)
        end
        
        ## the queue is not empty and more than timeout has passed 
        ## since the front-end was notified
        if (val[0] > 0 && val[1].nil?)
        
        
          
        end
         
      end

      def events_queue_key
        "events/queue"
      end
      
      def events_ping_key
        "events/ping"
      end
      
      def events_id_key
        "events/id"
      end
      
      
    end
  end
end
