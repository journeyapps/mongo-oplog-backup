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
      # Accepts {'t' => seconds, 'i' => increment}
      def from_json(data)
        self.new(data['t'], data['i'])
      end
    end

  end
end

::BSON::Timestamp.__send__(:include, Comparable)
::BSON::Timestamp.__send__(:include, MongoOplogBackup::Ext::Timestamp)
::BSON::Timestamp.extend(MongoOplogBackup::Ext::Timestamp::ClassMethods)
