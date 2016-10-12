RSpec.describe StackMaster::ParameterResolvers::SecretAnsibleVault do
  let(:base_dir) { 'spec/fixtures' }
  let(:config) { double(base_dir: base_dir) }
  let(:cli) { double(HighLine.new) }
  let(:stack_definition) { double(secret_file: secrets_file_name, stack_name: 'mystack', region: 'us-east-1') }
  subject(:resolve_secret) { StackMaster::ParameterResolvers::SecretAnsibleVault.new(config, stack_definition, cli).resolve(value) }
  let(:value) { 'key' }
  let(:secrets_file_name) { "my_secrets.yml" }
  let(:file_path) { "#{base_dir}/secrets/#{secrets_file_name}" }

  context 'the secret file does not exist' do
    before do
      allow(File).to receive(:exist?).with(file_path).and_return(false)
    end

    it 'raises an ArgumentError with the location of the expected secret file' do
      expect {
        resolve_secret
      }.to raise_error(ArgumentError, /#{file_path}/)
    end
  end

  context 'no secret file is specified for the stack definition' do
    before do
      allow(stack_definition).to receive(:secret_file).and_return(nil)
    end

    it 'raises an ArgumentError with the location of the expected secret file' do
      expect {
        resolve_secret
      }.to raise_error(ArgumentError, /No secret_file defined/)
    end
  end

  context 'the secret file exists' do
    before do
      expect(cli).to receive(:ask).and_return('123456')
    end

    context 'the secret key does not exist' do
      let(:value) { 'nokey' }
      it 'raises a secret not found error' do
        expect {
          resolve_secret
        }.to raise_error(StackMaster::ParameterResolvers::SecretAnsibleVault::SecretNotFound)
      end
    end#

    context 'the secret key exists' do

      it 'returns the secret' do
        expect(resolve_secret).to eq('secret')
      end
    end
  end
end
