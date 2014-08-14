module MongoOplogBackup
  module Oplog
    def self.merge(target, source_files, options={})
      limit = options[:limit] # TODO: use
      force = options[:force]

      File.open(target, 'wb') do |output|
        last_timestamp = nil
        first = true

        source_files.each do |filename|
          puts "Reading #{filename}"
          last_file_timestamp = nil
          skipped = 0
          wrote = 0
          each_document(filename) do |doc|
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

          puts "Wrote #{wrote} and skipped #{skipped} oplog entries"
          raise "Overlap must be exactly 1" unless first || skipped == 1 || force
          first = false
        end
      end
    end

  end
end