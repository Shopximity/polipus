module Polipus
  module UrlTracker
    class Cached
      attr_reader :cache
      attr_reader :tracker

      def initialize(options = {})
        require 'lru_redux'
        @tracker = tracker_class(options).new(options[:options])
        @cache = LruRedux::ThreadSafeCache.new(options[:size])
      end

      def visited?(url)
        @cache[url] || @tracker.visited?(url).tap do |result|
          @cache[url] = true if result
        end
      end

      def visit(url)
        @tracker.visit(url).tap do
          @cache[url] = true
        end
      end

      def remove(url)
        @tracker.remove(url).tap do
          @cache.delete(url)
        end
      end

      def clear
        @cache.clear
        @tracker.clear
      end

      private

      def tracker_class(options)
        tracker_path = "polipus/url_tracker/#{options[:tracker]}"
        constantize(to_classname(tracker_path))
      rescue NameError
        require tracker_path
        constantize(to_classname(tracker_path))
      end

      def to_classname(term)
        string = term.to_s
        string = string.sub(/^[a-z\d]*/) { $&.capitalize }
        string.gsub!(/(?:_|(\/))([a-z\d]*)/i) { "#{$1}#{$2.capitalize}" }
        string.gsub!('/', '::')
        string
      end

      def constantize(camel_cased_word)
        # From ActiveSupport

        names = camel_cased_word.split('::')

        # Trigger a builtin NameError exception including the ill-formed constant in the message.
        Object.const_get(camel_cased_word) if names.empty?

        # Remove the first blank element in case of '::ClassName' notation.
        names.shift if names.size > 1 && names.first.empty?

        names.inject(Object) do |constant, name|
          if constant == Object
            constant.const_get(name)
          else
            candidate = constant.const_get(name)
            next candidate if constant.const_defined?(name, false)
            next candidate unless Object.const_defined?(name)

            # Go down the ancestors to check it it's owned
            # directly before we reach Object or the end of ancestors.
            constant = constant.ancestors.inject do |const, ancestor|
              break const if ancestor == Object
              break ancestor if ancestor.const_defined?(name, false)
              const
            end

            # owner is in Object, so raise
            constant.const_get(name, false)
          end
        end
      end

    end
  end
end
