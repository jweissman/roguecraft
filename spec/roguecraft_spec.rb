require 'spec_helper'
require 'roguecraft'

describe Roguecraft do
  it "should have a VERSION constant" do
    subject.const_get('VERSION').should_not be_empty
  end
end
