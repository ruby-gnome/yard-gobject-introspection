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
    gir_document = REXML::Document.new file

    @klasses_yo = {}
    @xml_klasses_queue = []

    @module_yo = register ModuleObject.new(namespace, @module_name)
    version = gir_document.elements["repository/namespace"].attributes["version"]
    @module_yo.docstring = "@version #{version}"

    gir_document.elements.each("repository/namespace/class") do |klass|
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

    gir_document.elements.each("repository/namespace/constant") do |constant|
      name = constant.attributes["name"]
      value = constant.attributes["value"]
      documentation = read_doc(constant)
      register_constant(@module_yo, name, value, documentation)
    end

    gir_document.elements.each("repository/namespace/enumeration") do |enum|
      name = enum.attributes["name"]
      enum_mod = ModuleObject.new(@module_yo, name)
      documentation = read_doc(enum)
      val = 0
      enum.elements.each("member") do |member|
        member_name = member.attributes["name"]
        value = "#{member.attributes["value"] || val} or :#{member_name}"
        documentation = read_doc(member)
        register_constant(enum_mod, member_name.upcase, value, documentation)
        val += 1
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

  def register_constant(namespace, name, value, doc)
    const = ConstantObject.new(namespace, name)
    const.value = value
    const.docstring = doc
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
      ret_infos = read_return_value_information(m.elements["return-value"])
      documentation += "\n@return [#{ret_infos[:type]}] #{ret_infos[:doc]}"
      method.docstring = documentation
    end
  end

  def read_parameter_information(node)
    name = node.attributes["name"]
    type = nil
    if node.elements["type"]
      type = ctypes_to_ruby(node.elements["type"].attributes["name"])
    elsif node.elements["array"]
      type = node.elements["array/type"].attributes["name"]
      type = "Array<#{ctypes_to_ruby(type)}>"
    elsif name == "..."
      type = "Array"
      name = "array"
    else
      puts "Err Other type for #{name} parameter"
    end

    {:name => name, :type => type, :doc => read_doc(node)}
  end

  def read_return_value_information(node)
    type = nil
    if node.elements["type"]
      type = ctypes_to_ruby(node.elements["type"].attributes["name"])
    elsif node.elements["array"]
      type = node.elements["array/type"].attributes["name"]
      type = "Array<#{ctypes_to_ruby(type)}>"
    else
      puts "Err Other type for #{type} return value"
    end

    {:type => type, :doc => read_doc(node)}
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

