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

    @klasses_yo = {}
    @xml_klasses_queue = []

    @module_yo = register ModuleObject.new(namespace, module_name)

    doc.elements.each("repository/namespace/class") do |klass|
      parent_klass = klass.attributes["parent"]

      if parent_klass == nil || parent_klass == "GObject.Object"
        build_class_object(klass, @module_yo)
      elsif @klasses_yo[parent_klass]
        build_class_object(klass, @klasses_yo[parent_klass])
      else
        @xml_klasses_queue << klass
        next
      end
    end

    @xml_klasses_queue.each do |klass|
      parent_klass = klass.attributes["parent"]

      if parent_klass == nil || parent_klass == "GObject.Object"
        build_class_object(klass, @module_yo)
      elsif @klasses_yo[parent_klass]
        build_class_object(klass, @klasses_yo[parent_klass])
      else
        # TODO : improve.
        # is this condition is used, it means that the parent is
        # not a known class in this module
        build_class_object(klass, @module_yo)
      end
    end
  end

  private

  def build_class_object(klass, parent)
    klass_name = klass.attributes["name"]
    klass_yo = ClassObject.new(parent, klass_name)
    @klasses_yo[klass_name] = klass_yo
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

