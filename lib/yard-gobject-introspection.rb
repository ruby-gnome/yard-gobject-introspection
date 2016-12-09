require "yard"
require "rexml/document"

class GObjectIntropsectionHandler < YARD::Handlers::Ruby::Base
  handles :module

  def process
    gir_path = "/usr/share/gir-1.0"

    @module_name = statement[0].source
    girs_files = Dir.glob("#{gir_path}/#{@module_name}-?.*gir")
    gir_file = girs_files.last
    file = File.new(gir_file)
    doc = REXML::Document.new file

    @klasses_yo = {}
    @xml_klasses_queue = []

    @module_yo = register ModuleObject.new(namespace, @module_name)

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
    documentation ? parse_gtk_doc_tags(documentation.text) : ""
  end

  def parse_gtk_doc_tags(doc)
    # Substitue #GtkSomething to Gtk::Something
    parsed = doc.gsub(/\#([A-Z]+[a-z]+)([A-Z]+.*)/, '\1::\2')
    # Manage @parameter to <b>parameter</b>
    parsed.gsub!(/@(\w+)/,'<b>\1</b>')
    # Replace Null terminated array
    parsed.gsub!(/a %NULL-terminated array/,"an array")
    # Replace %NULL with nil
    parsed.gsub!(/%NULL/, "nil")
    # Replace %TRUE %FALSE
    parsed.gsub!(/%TRUE/, "true")
    parsed.gsub!(/%FALSE/, "false")
    parsed
  end

  def register_methods(klass, klass_yo)
    _register_methods(klass, klass_yo, "method")
  end

  def register_constructors(klass, klass_yo)
    _register_methods(klass, klass_yo, "constructor")
  end

  def _register_methods(klass, klass_yo, method_type)
    klass.elements.each(method_type) do |m|
      method = MethodObject.new(klass_yo, m.attributes["name"])
      documentation = read_doc(m)
      parameters = []
      m.elements.each("parameters/parameter") do |p|
        infos = read_parameter_information(p)
        documentation += "\n@param #{infos[:name]} [#{infos[:type]}] #{infos[:doc]}"
        parameters << [infos[:name], nil]
      end
      method.parameters = parameters
      method.docstring = documentation
    end
  end

  def read_parameter_information(node)
    pname = node.attributes["name"]
    ptype = nil
    if node.elements["type"]
      ptype = ctypes_to_ruby(node.elements["type"].attributes["name"])
    elsif node.elements["array"]
      ptype = node.elements["array/type"].attributes["name"]
      ptype = "Array<#{ctypes_to_ruby(ptype)}>"
    elsif pname == "..."
      ptype = "Array"
      pname = "array"
    else
      puts "Err Other type for #{pname} parameter"
    end

    pdoc = read_doc(node)
    {:name => pname, :type => ptype, :doc => pdoc}
  end

  def ctypes_to_ruby(ctype)
    case ctype
    when /(guint8)|(gsize)|(gint)|(guint)/
      "Integer"
    when "gdouble"
      "Float"
    when "utf8"
      "String"
    when "gboolean"
      "TrueClass"
    when /.*\..*/
      ctype.gsub("\.", "::")
    else
      "#{@module_name}::#{ctype}"
    end
    # TODO : manage :
    # va_list
    # gpointer
    # gsf_off_t
    # gpointer
    # gsf_off_t
  end
end

