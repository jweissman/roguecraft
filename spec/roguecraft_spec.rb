require 'spec_helper'
require 'minotaur'
require 'roguecraft'
require 'roguecraft/hero'
require 'roguecraft/game'
require 'pry'
# require 'roguecraft/dungeon'

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

describe Roguecraft::Game do
  context "generating a dungeon" do
    its(:dungeon) { should_not be_nil }
    its(:dungeon) { should be_a(Minotaur::Dungeon) }
    its('dungeon.levels') { should be_a(Array) }
    its('dungeon.levels.first') { should be_a(Minotaur::Labyrinth) }
    its('dungeon.levels.size') { should eql(Roguecraft::Game::DEFAULT_DEPTH)}
  end

  context "#current_level" do
    its(:current_depth) { should eql(0) }
    it 'should indicate the first level as current_level' do
      subject.dungeon.levels.first.should eql(subject.current_level)
    end

    it 'should generate a map' do
      subject.map.should be_a(Array)
      subject.map.first.should be_a(Array)
      subject.map.first.first.should be_a(Integer)
      subject.map.size.should eql(subject.height)
      subject.map.first.size.should eql(subject.width)
    end

    let(:hero) { subject.hero }

    it 'should place hero on an open spot' do
      subject.at(hero.x, hero.y).should eql(0)
    end
  end

  # generating a town?
end

# describe Roguecraft::Dungeon do
#   its('levels.count') { 25 }
#   its('levels.first') { should be_a(Roguecraft::Dungeon::Level) }
# end
# 
# describe Roguecraft::Dungeon::Level do
#   its('rooms.count')    { should be > 5 }
#   
#   its('enemies.count')  { should be > 1 }
#   its('treasure.count') { should be > 1 }
#   its('traps.count')    { should be > 1 }
#   its('secrets.count')   { should be > 1 }
# 
#   it 'should generate a map' do
#     @level = Roguecraft::Dungeon::Level.new
#     @level.map.should_not be_nil
#     @level.map.first.first.should be_a(Roguecraft::Dungeon::Tile)
#   end
# end
# 
# describe Roguecraft::Dungeon::Room do
# end
