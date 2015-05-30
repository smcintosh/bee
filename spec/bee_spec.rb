require 'spec_helper'

describe Bee do
  it 'has a version number' do
    expect(Bee::VERSION).not_to be nil
  end

  it 'can load GDF data' do
    gdffile = File.expand_path("../data/patchelf.gdf", __FILE__)
    loader = Bee::GDFLoader.new(gdffile, Bee::Neo4jWriter.new(BEEFILE), Bee::Autotools.new)
    expect(loader.load).to eq(true)
  end

  it 'can load GDF XML data' do
    gdfxmlfile = File.expand_path("../data/patchelf.gdf.xml", __FILE__)
    loader = Bee::GDFXMLLoader.new(gdfxmlfile, Bee::Neo4jWriter.new(BEEFILE), Bee::Autotools.new)
    expect(loader.load).to eq(true)
  end

  it 'can load STrace data' do
    stracefile = File.expand_path("../data/patchelf.strace", __FILE__)
    loader = Bee::STraceLoader.new(stracefile, Bee::Neo4jWriter.new(BEEFILE), Bee::Autotools.new, "/home/shane/src/patchelf-0.8")
    expect(loader.load).to eq(true)
  end
end
