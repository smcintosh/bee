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
      @logger.info("=== STARTING GDFXMLLoader ===")

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
      @logger.info("= Removing crap from database")
      remove_implicit
      @logger.info("DONE")
      @logger.info("=== FINISHED GDFXMLLoader ===")
    end

    def remove_implicit
      #Neo4j::Session.query.match("(n {implicit:true})").optional_match("(n)-[r]-()").return("n,r").delete("n,r")

      # .optional_match("(n)-[r]-()").delete("n,r")
      Neo4j::Session.query("MATCH (n {implicit:true}) OPTIONAL MATCH (n)-[r]-() DELETE n,r")
    end
  end
end
