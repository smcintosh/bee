# Makao GDF XML

require 'rexml/document'
require 'pathname'
require 'uri'

module Bee
  class GDFXMLLoader
    def initialize(fname, writer)
      @xmldata = REXML::Document.new(File.new(fname)) 
      @writer = writer
    end

    def load
      @xmldata.elements.each("build/target") do |element|
        name = element.attribute("name").to_s
        cmd = ""
        element.elements.each("actual_command") do |command|
          cmd << "#{command.text.to_s}; "
        end

        node = @writer.getNodeByName(name, true)
        @writer.addProperty(node, :command, cmd)
      end
    end
  end
end
