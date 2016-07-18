require 'digest/md5'

module StackMaster
  module AwsDriver
    class S3ConfigurationError < StandardError; end

    class S3
      def set_region(region)
        @region = region
        @s3 = nil
      end

      def upload_files(bucket: nil, prefix: nil, region: nil, files: {})
        raise StackMaster::AwsDriver::S3ConfigurationError, 'A bucket must be specified in order to use S3' unless bucket

        s3 = new_s3_client(region: region)

        return if files.empty?

        current_objects = s3.list_objects(
          prefix: prefix,
          bucket: bucket
        ).map(&:contents).flatten.inject({}){|h,obj|
          h.merge(obj.key => obj)
        }

        files.each do |template, file|
          body = file[:body]
          file = file[:path]
          key = template.dup
          key.prepend("#{prefix}/") if prefix
          raw_template_md5 = Digest::MD5.file(file).to_s
          compiled_template_md5 = Digest::MD5.hexdigest(body).to_s
          s3_md5 = current_objects[key] ? current_objects[key].etag.gsub("\"", '') : nil

          next if [raw_template_md5, compiled_template_md5].include?(s3_md5)
          StackMaster.stdout.puts "Uploading #{file} to bucket #{bucket}/#{key}..."

          s3.put_object(
            bucket: bucket,
            key: key,
            body: body,
            metadata: { md5: compiled_template_md5 }
          )
        end
      end

      def url(bucket: bucket, prefix: prefix, region: region, template: template)
        if region == 'us-east-1'
          ["https://s3.amazonaws.com", bucket, prefix, template].compact.join('/')
        else
          ["https://s3-#{region}.amazonaws.com", bucket, prefix, template].compact.join('/')
        end
      end

      private

      def new_s3_client(region: nil)
        Aws::S3::Client.new(region: region || @region)
      end
    end
  end
end
