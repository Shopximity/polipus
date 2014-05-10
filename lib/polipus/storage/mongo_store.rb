require "mongo"
require "zlib"
require "thread"
module Polipus
  module Storage
    class MongoStore < Base
      TOO_LARGE = 'too_large'
      BINARY_FIELDS = %w(body headers data)

      def initialize(options = {})
        @mongo      = options[:mongo]
        @collection = options[:collection]
        @mongo.create_collection(@collection)
        @mongo[@collection].ensure_index(:uuid, :unique => true, :drop_dups => true, :background => true)
        @compress_body = options[:compress_body] ||= true
        @except = options[:except] ||= []
        @semaphore = Mutex.new
      end

      def add page
        @semaphore.synchronize {
          obj = page.to_hash
          @except.each {|e| obj.delete e.to_s}
          obj['uuid'] = uuid(page)
          obj['body'] = body_value(obj['body'])
          BINARY_FIELDS.each do |field|
            obj[field] = BSON::Binary.new(obj[field]) unless obj[field].nil?
          end
          safe_save(obj)
        }
      end
      
      def exists?(page)
        @semaphore.synchronize {
          doc = @mongo[@collection].find({:uuid => uuid(page)}, {:fields => [:_id]}).limit(1).first
          !doc.nil?
        }
      end

      def get page
        @semaphore.synchronize {
          data = @mongo[@collection].find({:uuid => uuid(page)}).limit(1).first
          return load_page(data) if data
        }
      end

      def remove page
        @semaphore.synchronize {
          @mongo[@collection].remove({:uuid => uuid(page)})
        }
      end

      def count
        @mongo[@collection].count
      end

      def each
        @mongo[@collection].find({},:timeout => false) do |cursor|
          cursor.each do |doc|
            page = load_page(doc)
            yield doc['uuid'], page
          end
        end
      end

      def clear
        @mongo[@collection].drop
      end

      private

        def body_value(value)
          Zlib::Deflate.deflate(value) if @compress_body && value
        end

        def safe_save(obj)
          save(obj)
        rescue BSON::InvalidDocument => e
          if /too large/i =~ e.msg && obj['body'] && obj['body'].size > 1_000
            # Remove the body; mark document as too large & retry
            obj['body'] = BSON::Binary.new(body_value(''))
            obj[TOO_LARGE] = true
            retry
          else
            raise
          end
        end

        def save(obj)
          @mongo[@collection].update({:uuid => obj['uuid']}, obj, {:upsert => true, :w => 1})
          obj['uuid']
        end

        def load_page(hash)
          BINARY_FIELDS.each do |field|
            hash[field] = hash[field].to_s
          end
          begin
            hash['body'] = Zlib::Inflate.inflate(hash['body']) if @compress_body && hash['body'] && !hash['body'].empty?
            page = Page.from_hash(hash)
            if page.fetched_at.nil?
              page.fetched_at = hash['_id'].generation_time.to_i
            end
            return page
          rescue
          end
          nil
        end

    end
  end
end
