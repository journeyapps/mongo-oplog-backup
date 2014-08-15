module MongoOplogBackup
  module Oplog
    def self.each_document(filename)
      File.open(filename, 'rb') do |stream|
        while !stream.eof?
          yield BSON::Document.from_bson(stream)
        end
      end
    end

    def self.oplog_timestamps(filename)
      timestamps = []
      each_document(filename) do |doc|
        # This can be optimized by only decoding the timestamp
        # (first field), instead of decoding the entire document.
        timestamps << doc['ts']
      end
      timestamps
    end

    def self.merge(target, source_files, options={})
      limit = options[:limit] # TODO: use
      force = options[:force]

      File.open(target, 'wb') do |output|
        last_timestamp = nil
        first = true

        source_files.each do |filename|
          # Optimize:
          # We can assume that the timestamps are in order.
          # This means we only need to find the first non-overlapping point,
          # and the rest we can pass through directly.
          MongoOplogBackup.log.debug "Reading #{filename}"
          last_file_timestamp = nil
          skipped = 0
          wrote = 0
          Oplog.each_document(filename) do |doc|
            timestamp = doc['ts']
            if !last_timestamp.nil? && timestamp <= last_timestamp
              skipped += 1
            elsif !last_file_timestamp.nil? && timestamp <= last_file_timestamp
              raise "Timestamps out of order in #{filename}"
            else
              output.write(doc.to_bson)
              wrote += 1
              last_timestamp = timestamp
            end
            last_file_timestamp = timestamp
          end

          MongoOplogBackup.log.info "Wrote #{wrote} and skipped #{skipped} oplog entries from #{filename}"
          raise "Overlap must be exactly 1" unless first || skipped == 1 || force
          first = false
        end
      end
    end

  end
end