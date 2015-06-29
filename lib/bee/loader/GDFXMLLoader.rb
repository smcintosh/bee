# Makao GDF XML

require 'rexml/document'
require 'pathname'
require 'uri'

module Bee
  class GDFXMLLoader < Loader
    def initialize(config)
      super(config.get(:gdfxml_file), config)
    end

    def node(name, cmd)
      if (!isJunk(name))
        @logger.debug("Updating #{name} with command #{cmd}")
        node = @writer.getNode(:name, name)
        @writer.addProperty(node, :command, cmd)
      end
    end

    def load_hook
      xmlfile = File.new(@fname)
      xmldata = REXML::Document.new(xmlfile)

      xmldata.elements.each("build/target") do |element|
        name = element.attribute("name").to_s
        cmd = ""
        element.elements.each("actual_command") do |command|
          cmd << "#{command.text.to_s}; "
        end

        node(name, cmd)
      end
    end
  end
end
