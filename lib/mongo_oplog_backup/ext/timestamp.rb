# Make BSON::Timestamp comparable
require 'date'
require 'bson'

module MongoOplogBackup::Ext
  module Timestamp
    def <=> other
      [seconds, increment] <=> [other.seconds, other.increment]
    end

    def to_s
      "#{seconds}:#{increment}"
    end

    def hash
      to_s.hash
    end

    def eql? other
      self == other
    end

    module ClassMethods
      # Accepts {'t' => seconds, 'i' => increment} or {'$timestamp' => {'t' => seconds, 'i' => increment}}
      def from_json(data)
        data = data['$timestamp'] if data['$timestamp']
        self.new(data['t'], data['i'])
      end

      # Accepts: <seconds>[:ordinal]
      def from_string(string)
        match = /(\d+)(?::(\d+))?/.match(string)
        return nil unless match
        s1 = match[1].to_i
        i1 = match[2].to_i
        self.new(s1,i1)
      end
    end

  end
end

::BSON::Timestamp.__send__(:include, Comparable)
::BSON::Timestamp.__send__(:include, MongoOplogBackup::Ext::Timestamp)
::BSON::Timestamp.extend(MongoOplogBackup::Ext::Timestamp::ClassMethods)
