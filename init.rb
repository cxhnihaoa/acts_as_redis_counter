# Include hook code here
require 'acts_as_redis_counter'

ActiveRecord::Base.send(:include, ActsAsRedisCounter)
