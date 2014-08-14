# Make BSON::Timestamp comparable
require 'bson'

module MongoOplogBackup::Ext
  module Timestamp
    def <=> other
      [seconds, increment] <=> [other.seconds, other.increment]
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
