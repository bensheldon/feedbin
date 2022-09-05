# frozen_string_literal: true

module Crawler
  module Image
    class Download
      attr_reader :path

      def initialize(url, minimum_size: 20_000)
        @url = url
        @valid = false
        @minimum_size = minimum_size
      end

      def self.download!(url, **args)
        klass = find_download_provider(url) || Download::Default
        instance = klass.new(url, **args)
        instance.download
        instance
      end

      def image_url
        @url
      end

      def download_file(url)
        @file = Down.download(url, max_size: 10 * 1024 * 1024, timeout_options: {read_timeout: 20, write_timeout: 5, connect_timeout: 5})
        @path = @file.path
      end

      def persist!
        unless @path == persisted_path
          FileUtils.mv @path, persisted_path
          @path = persisted_path
        end
        persisted_path
      end

      def delete!
        @file.respond_to?(:close) && @file.close
        @file.respond_to?(:unlink) && @file.unlink
        @path && File.unlink(@path)
      rescue Errno::ENOENT
      end

      def persisted_path
        @persisted_path ||= File.join(Dir.tmpdir, ["image_original_", SecureRandom.hex].join)
      end

      def valid?
        valid = @file && @file.content_type&.start_with?("image")
        valid &&= @file.size >= @minimum_size unless @minimum_size.nil?
        valid
      end

      def provider_identifier
        self.class.recognize_url?(@url)
      end

      def self.recognize_url?(src_url)
        if supported_urls.find { src_url.to_s =~ _1 }
          Regexp.last_match[1]
        else
          false
        end
      end

      def self.find_download_provider(url)
        download_providers.detect { |klass| klass.recognize_url?(url) }
      end

      def self.download_providers
        [
          Download::Youtube,
          Download::Instagram,
          Download::Vimeo
        ]
      end

      def self.supported_urls
        []
      end
    end
  end
end