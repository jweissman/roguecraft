require 'spec_helper'
require 'roguecraft'
require 'roguecraft/hero'
require 'roguecraft/dungeon'

describe Roguecraft do
  it "should have a VERSION constant" do
    subject.const_get('VERSION').should_not be_empty
  end
end

describe Roguecraft::Hero do
  context "starting stats" do
    its(:hp)  { 30 }

    its(:str) { 10 }
    its(:con) { 10 }
    its(:dex) { 10 }
    its(:wis) { 10 }
  end
end

describe Roguecraft::Dungeon do
  its('levels.count') { 25 }
  its('levels.first') { should be_a(Roguecraft::Dungeon::Level) }
end

describe Roguecraft::Dungeon::Level do
  its('rooms.count')    { should be > 5 }
  
  its('enemies.count')  { should be > 1 }
  its('treasure.count') { should be > 1 }
  its('traps.count')    { should be > 1 }
  its('secrets.count')   { should be > 1 }

  it 'should generate a map' do
    @level = Roguecraft::Dungeon::Level.new
    @level.map.should_not be_nil
    @level.map.first.first.should be_a(Roguecraft::Dungeon::Tile)
  end
end

describe Roguecraft::Dungeon::Room do
end
