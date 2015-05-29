$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'bee'

BEEFILE = File.expand_path("../.beedb", __FILE__)

RSpec.configure do |config|
  config.before(:all) do
    FileUtils.rm_rf(BEEFILE)
  end
end
