require "yard"
require "rexml/document"
include REXML

class GObjectIntropsectionHandler < YARD::Handlers::Ruby::Base
  handles :module

  def process
    gir_path = "/usr/share/gir-1.0"

    module_name = statement[0].source
    girs_files = Dir.glob("#{gir_path}/#{module_name}-?.*gir")
    gir_file = girs_files.last
    file = File.new(gir_file)
    doc = Document.new file

    module_yo = register ModuleObject.new(namespace, module_name)
    doc.elements.each("repository/namespace/class") do |klass|
      klass_name = klass.attributes["name"]
      klass_yo = ClassObject.new(module_yo, klass_name)
      documentation = klass.elements["doc"]
      klass_yo.docstring = documentation ? documentation.text : ""

      klass.elements.each("constructor") do |c|
        m = MethodObject.new(klass_yo, c.attributes["name"])
        documentation = c.elements["doc"]
        m.docstring = documentation ? documentation.text : ""
      end

      klass.elements.each("method") do |c|
        m = MethodObject.new(klass_yo, c.attributes["name"])
        documentation = c.elements["doc"]
        m.docstring = documentation ? documentation.text : ""
      end
    end

  end
end

