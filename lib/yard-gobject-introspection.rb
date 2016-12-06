require "yard"
require "rexml/document"

class GObjectIntropsectionHandler < YARD::Handlers::Ruby::Base
  handles :module

  def process
    gir_path = "/usr/share/gir-1.0"

    module_name = statement[0].source
    girs_files = Dir.glob("#{gir_path}/#{module_name}-?.*gir")
    gir_file = girs_files.last
    file = File.new(gir_file)
    doc = REXML::Document.new file

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
    klass_yo.docstring = read_doc(klass)

    register_constructors(klass, klass_yo)

    register_methods(klass, klass_yo)
  end

  def read_doc(node)
    documentation = node.elements["doc"]
    documentation ? documentation.text : ""
  end

  def register_methods(klass, klass_yo)
    klass.elements.each("method") do |m|
      method = MethodObject.new(klass_yo, m.attributes["name"])
      method.docstring = read_doc(m)
    end
  end

  def register_constructors(klass, klass_yo)
    klass.elements.each("constructor") do |c|
      method = MethodObject.new(klass_yo, c.attributes["name"])
      method.docstring = read_doc(c)
    end
  end
end

