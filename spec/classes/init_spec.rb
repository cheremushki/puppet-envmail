require 'spec_helper'
describe 'env_tagmail' do

  context 'with defaults for all parameters' do
    it { should contain_class('tagmail') }
  end
end
