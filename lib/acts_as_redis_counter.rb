# ActsAsRedisCounter
module ActsAsRedisCounter #:nodoc:
    def self.included(base)
      base.extend ClassMethods
    end

    module ClassMethods
      def acts_as_redis_counter(*attributes)

        options = attributes.last.is_a?(Hash) ? attributes.pop : {}
        options = {
          :ttl => 5.minutes,
          :hits => 100
        }.merge(options)


        attributes.each do |attribute|
          # inc method
          define_method("redis_counter_#{attribute}_inc") do |*args|
            n = args.first || 1
            key = redis_counter_key(attribute)

            send("redis_counter_load_#{attribute}")
            REDIS.incr(key, n)
            send("redis_counter_flush_#{attribute}")
            REDIS[key]
          end

          # getter
          define_method("redis_counter_#{attribute}") do
            key = redis_counter_key(attribute)
            REDIS[key] = send(attribute) if REDIS[key].nil?
            REDIS[key]
          end

          # load from db
          define_method("redis_counter_load_#{attribute}") do
            key = redis_counter_key(attribute)
            REDIS[key] = send(attribute) if REDIS[key].nil?
          end

          # save to db
          define_method("redis_counter_flush_#{attribute}") do
            redis_value = send("redis_counter_#{attribute}").to_i
            db_value = send(attribute).to_i
            hits = options[:hits].to_i

            ttl_key = redis_counter_ttl_key(attribute)
            expired = REDIS[ttl_key].nil?

            # save to db
            if (redis_value - db_value) > hits or expired
              send(:update_attribute, attribute, redis_value)

              # set ttl key expiration
              REDIS.set(ttl_key, 1, options[:ttl].to_i)
            end
          end

          # declare private methods
          private "redis_counter_load_#{attribute}"
          private "redis_counter_flush_#{attribute}"
        end

        include ActsAsRedisCounter::InstanceMethods
        extend ActsAsRedisCounter::SingletonMethods
      end
    end

    module SingletonMethods
    end

    module InstanceMethods
    private
      def redis_counter_key(attribute)
        "redis_counter_#{self.class.name.downcase}_#{self.id}_#{attribute}"
      end

      def redis_counter_ttl_key(attribute)
        redis_counter_key(attribute) + "_ttl"
      end
    end
end

