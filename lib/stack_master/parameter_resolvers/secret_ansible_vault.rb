require 'ansible/vault'
require 'highline'

module StackMaster
  module ParameterResolvers
    class SecretAnsibleVault < Resolver
      SecretNotFound = Class.new(StandardError)

      array_resolver

      def initialize(config, stack_definition, highline = HighLine.new)
        @config = config
        @stack_definition = stack_definition
        @highline = highline
      end

      def resolve(value)
        secret_key = value
        raise ArgumentError, "No secret_file defined for stack definition #{@stack_definition.stack_name} in #{@stack_definition.region}" unless !@stack_definition.secret_file.nil?
        raise ArgumentError, "Could not find secret file at #{secret_file_path}" unless File.exist?(secret_file_path)
        secrets_hash.fetch(secret_key) do
          raise SecretNotFound, "Unable to find key #{secret_key} in file #{secret_file_path}"
        end
      end

      private

      def secrets_hash
        @secrets_hash ||= YAML.load(decrypt_with_ansible_vault)
      end

      def decrypt_with_ansible_vault
        Ansible::Vault.read(path: secret_file_path, password: password)
      end

      def secret_path_relative_to_base
        @secret_path_relative_to_base ||= File.join('secrets', @stack_definition.secret_file)
      end

      def secret_file_path
        @secret_file_path ||= File.join(@config.base_dir, secret_path_relative_to_base)
      end

      def password
        @highline.ask("Enter your Ansible Vault password:  ") { |q| q.echo = "x" }
      end
    end
  end
end
