require 'capistrano'
require 'capistrano/version'

module CapistranoScale
  class CapistranoIntegration
    def self.load_into(capistrano_config)
      capistrano_config.load do
        namespace :scale_copy do

          desc "Internal hook that updates the aws_install.sh script to latest if the deploy completed"
          task :store_aws_install_script_on_success do
            install_cmd_path = fetch(:s3_install_cmd_path)

            if install_cmd_path
              aws_credentials = {
                :aws_access_key_id     => capistrano_config[:aws_access_key_id],
                :aws_secret_access_key => capistrano_config[:aws_secret_access_key]
              }
              aws_connection = Fog::Storage::AWS.new(aws_credentials)
              aws_directory = aws_connection.directories.create(
                :key        => capistrano_config[:aws_releases_bucket],
                :public     => false
              )
              logger.debug "Uploading #{install_cmd_path} initialization script to S3"
              key = "#{rails_env}/#{application}/aws_install.sh"
              existing = aws_directory.files.get(key)
              existing.destroy if existing
              file = aws_directory.files.new(
                :key        => key,
                :body       => File.open(install_cmd_path),
                :acl        => 'public-read',
                :encryption => 'AES256'
              )
              begin
                file.save
                logger.debug "AWS Install script uploaded in #{key}"
              rescue => e
                raise(Capistrano::Error, "S3 File upload failed: #{e.class.to_s}:#{e.message}")
              end
            end
          end
        end

        after 'deploy', 'scale_copy:store_aws_install_script_on_success'
      end
    end
  end
end

if Capistrano::Configuration.instance
  CapistranoScale::CapistranoIntegration.load_into(Capistrano::Configuration.instance)
end
