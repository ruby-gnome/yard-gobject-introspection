require "yard"
require "gobject-introspection"

class GObjectIntropsectionHandler < YARD::Handlers::Ruby::Base
  handles :module

  def process
    base = File.join(File.dirname(File.expand_path(statement.file)))
    $LOAD_PATH.unshift(base)

    puts "-- Load module info"

    require File.expand_path(statement.file)
    module_name = statement[0].source
    puts module_name
    current_module = Object.const_get("#{module_name}")
    current_module.init if current_module.respond_to?(:init)

    current_module.constants.each do |c|
      puts "#{c} #{current_module.const_get(c).class}"
    end
  end
end
