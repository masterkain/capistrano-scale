require 'capistrano/recipes/deploy/strategy/copy'
require 'erb'
require 'fog'

module Capistrano
  module Deploy
    module Strategy
      class ScaleCopy < Copy

        def initialize(config={})
          super(config)

          # Check configuration keys and raise error if something is missing.
          %w(aws_access_key_id aws_secret_access_key aws_releases_bucket aws_install_script aws_ec2_iam_role).each do |var|
            value = configuration[var.to_sym]
            if value.nil?
              raise(Capistrano::Error, "Missing configuration[:#{var}] setting")
            end
          end
          # Build up variables needed in the later execution.
          @aws_credentials = {
            :aws_access_key_id     => configuration[:aws_access_key_id],
            :aws_secret_access_key => configuration[:aws_secret_access_key]
          }
          @bucket_name = configuration[:aws_releases_bucket]
          @aws_shell_environment = @aws_credentials.collect{ |k,v| "#{k.upcase}=#{v}" }.join(' ')
          @aws_connection = Fog::Storage::AWS.new(aws_credentials)
          @aws_directory = @aws_connection.directories.create(
            :key        => bucket_name,
            :public     => false
          )
        end

        # Check if curl is installed on the remote server.
        def check!
          super.check do |d|
            d.remote.command("curl")
          end
        end

        # Distributes the file to the remote servers.
        def distribute!
          package_path = filename
          package_name = File.basename(package_path)

          package_key  = "#{rails_env}/#{application}/#{package_name}"

          file = aws_directory.files.new(
            :key        => package_key,
            :body       => File.open(package_path),
            :public     => false,
            :encryption => 'AES256'
          )

          logger.debug "Copying the package on S3: #{package_key}"
          if configuration.dry_run
            logger.debug file.inspect
          else
            begin
              file.save
            rescue => e
              raise(Capistrano::Error, "S3 File upload failed: #{e.class.to_s}:#{e.message}")
            end
          end
          logger.debug "Package copied."

          expiring_url = file.url(Time.now + 600)

          logger.debug "Fetching the release archive on the server"
          run "curl -s -L -o #{remote_filename} --url '#{expiring_url}'"
          logger.debug "Decompressing the release archive on the server"
          run "cd #{configuration[:releases_path]} && #{decompress(remote_filename).join(" ")} && rm #{remote_filename}"
          logger.debug "Release uncompressed, ready for hooks"

          logger.debug "Creating instance initialization script locally"

          template_text = File.read(configuration[:aws_install_script])
          template_text = template_text.gsub("\r\n?", "\n")
          template      = ERB.new(template_text, nil, '<>-')
          output        = template.result(self.binding)

          local_output_file = File.join(copy_dir, "#{rails_env}_aws_install.sh")

          File.open(local_output_file, "w") do  |f|
            f.write(output)
          end

          logger.debug "Script created at: #{local_output_file}"

          # Will be picked up by an internal Capistrano hook after a deploy has finished
          # to put this manifest on S3.
          configuration[:s3_install_cmd_path] = local_output_file
        end

        def binding
          super
        end

        def aws_credentials
          @aws_credentials
        end

        def aws_shell_environment
          @aws_shell_environment
        end

        def bucket_name
          @bucket_name
        end

        def aws_connection
          @aws_connection
        end

        def aws_directory
          @aws_directory
        end
      end
    end
  end
end
