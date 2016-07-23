RSpec.describe StackMaster::StackDependency do
  let(:region) { 'us-east-1' }
  let(:vpc_stack_name) { 'myapp-vpc' }
  let(:vpc_stack_definition) { StackMaster::StackDefinition.new(base_dir: '/base_dir', region: region, stack_name: vpc_stack_name) }
  let(:vpc_stack) do
    StackMaster::Stack.new(
      stack_id: '1',
      stack_name: vpc_stack_name,
      outputs: [
        {description: "", output_key: "vpc_id", output_value: "vpc-123"},
        {description: "", output_key: "subnet_1_id", output_value: "subnet-456"},
        {description: "", output_key: "subnet_2_id", output_value: "subnet-789"},
      ]
    )
  end
  let(:web_stack_name) { 'myapp-web' }
  let(:web_stack_definition) { StackMaster::StackDefinition.new(base_dir: '/base_dir', region: region, stack_name: web_stack_name) }
  let(:web_stack) do
    StackMaster::Stack.new(
      stack_id: '2',
      stack_name: web_stack_name,
      parameters: {
        "VpcId" => web_stack_vpc_id,
        "SubnetIds" => web_stack_subnet_ids,
      }
    )
  end
  let(:web_param_file) {
    <<-eos
    vpc_id:
      stack_output: myapp-vpc/vpc_id
    subnet_ids:
      stack_outputs:
        - myapp-vpc/subnet_1_id
        - myapp-vpc/subnet_2_id
    eos
  }
  let(:config) { double(find: vpc_stack, stacks: [vpc_stack_definition, web_stack_definition], region: region) }

  subject { described_class.new(vpc_stack_definition, config) }

  before do
    expect(File).to receive(:exists?).with('/base_dir/parameters/myapp_web.yml').and_return(true)
    allow(File).to receive(:exists?).and_call_original
    allow(File).to receive(:read).with('/base_dir/parameters/myapp_web.yml').and_return(web_param_file)
    allow(StackMaster::Stack).to receive(:find).with(region, web_stack_name).and_return(web_stack)
    allow(StackMaster::Stack).to receive(:find).with(region, vpc_stack_name).and_return(vpc_stack)
  end

  context 'when the web stacks parameters are up to date' do
    let(:web_stack_vpc_id) { "vpc-123" }
    let(:web_stack_subnet_ids) { "subnet-456,subnet-789" }

    it 'returns no outdated stacks' do
      expect(subject.outdated_stacks).to eq []
    end
  end

  context 'when the stack_output is out of date' do
    let(:web_stack_vpc_id) { "vpc-321" }
    let(:web_stack_subnet_ids) { "subnet-456,subnet-789" }

    it 'returns one outdated stack' do
      expect(subject.outdated_stacks).to eq [web_stack_definition]
    end
  end

  context 'when one of the stack_outputs is out of date' do
    let(:web_stack_vpc_id) { "vpc-123" }
    let(:web_stack_subnet_ids) { "subnet-654,subnet-789" }

    it 'returns one outdated stack' do
      expect(subject.outdated_stacks).to eq [web_stack_definition]
    end
  end

  context 'when the dependant stack does not exist' do
  end
end
