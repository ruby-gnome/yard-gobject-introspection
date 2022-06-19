require "yard"
require "rexml/document"
require "rbconfig"

class GObjectIntropsectionHandler < YARD::Handlers::Ruby::Base
  handles :module

  def process
    gir_path = File.expand_path("gir-1.0", RbConfig::CONFIG["datadir"])

    @module_name = statement[0].source
    girs_files = Dir.glob("#{gir_path}/#{@module_name}-?.*gir")
    gir_file = girs_files.last
    file = File.new(gir_file)
    gir_document = REXML::Document.new file

    @klasses_yo = {}
#    @xml_klasses_queue = []

    @module_yo = register ModuleObject.new(namespace, @module_name)
    version = gir_document.elements["repository/namespace"].attributes["version"]
    @module_yo.docstring = "@version #{version}"

    gir_document.elements.each("repository/namespace/*") do |element|
      case element.name
      when "class"
        parse_class_element(element)
      when "enumeration"
        parse_enumeration_element(element)
      when "bitfield"
        parse_enumeration_element(element)
      when "constant"
        parse_module_constant(element)
      when "function"
        parse_module_function(element)
      when "interface"
        parse_interface_module(element)
      when "record"
        parse_record_element(element)
      else
        STDERR.puts "!! #{element.name} type is not handled"
      end
    end

#    parse_orphan_class_element
  end

  private

  def build_object(klass)
    return unless block_given?

#    parent_klass = klass.attributes["parent"]

#    if parent_klass == nil || parent_klass == "GObject.Object"
      yield(klass, @module_yo)
#    elsif @klasses_yo[parent_klass]
#      yield(klass, @klasses_yo[parent_klass])
#    else
#      @xml_klasses_queue << klass
#    end
  end

  def parse_interface_module(klass)
    begin
      build_object(klass) do |k, p|
        build_module_object(k, p)
      end
    rescue => error
      STDERR.puts "Class #{klass.name} parsing error : #{error.message}"
    end
  end

  def parse_module_function(function)
    _register_module_function(function, @module_yo)
  end

  def parse_class_element(klass)
    begin
      build_object(klass) do |k, p|
        build_class_object(k, p)
      end
    rescue => error
      STDERR.puts "Class #{klass.name} parsing error : #{error.message}"
    end
  end

  def parse_record_element(klass)
    begin
      case klass.attributes["name"]
      when /Class\z/
        build_object(klass) do |k, p|
          build_record_class_object(k, p)
        end
      when /Iface\z/
        build_object(klass) do |k, p|
          build_record_module_object(k, p)
        end
      else
        STDERR.puts "Record not managed : #{klass.attributes["name"]}"
      end
    rescue => error
      STDERR.puts "Record #{klass.name} parsing error : #{error.message}"
    end
  end

  def parse_orphan_class_element
    begin
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
          STDERR.puts "Can not found Superclass for #{klass.attributes["name"]}"
          build_class_object(klass, @module_yo)
        end
      end
    rescue => error
      STDERR.puts "SubClass parsing error : #{error.message}"
    end
  end

  def parse_enumeration_element(enum)
    begin
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
    rescue => error
      STDERR.puts "#{enum.name.capitalize} parsing error: #{error.message}"
    end
  end

  def parse_module_constant(constant)
    begin
      name = constant.attributes["name"]
      value = constant.attributes["value"]
      documentation = read_doc(constant)
      register_constant(@module_yo, name, value, documentation)
    rescue => error
      STDERR.puts "Constants parsing error: #{error.message}"
    end
  end

  def build_class_object(klass, parent)
    klass_name = klass.attributes["name"]
    klass_yo = ClassObject.new(parent, klass_name)
    @klasses_yo[klass_name] = klass_yo
    klass_yo.docstring = read_doc(klass)
    register_constructors(klass, klass_yo)
    register_methods(klass, klass_yo)
    register_properties(klass, klass_yo)
  end

  def build_record_class_object(klass, parent)
    klass_name = klass.attributes["name"].gsub(/Class\z/,"")
    klass_yo = ClassObject.new(parent, klass_name)
    @klasses_yo[klass_name] = klass_yo
    klass_yo.docstring = read_doc(klass)
    register_constructors(klass, klass_yo)
    register_methods(klass, klass_yo)
    register_properties(klass, klass_yo)
  end

  def build_record_module_object(klass, parent)
    module_name = klass.attributes["name"].gsub(/Iface\z/,"")
    module_yo = ModuleObject.new(parent, module_name)
    @klasses_yo[module_name] = module_yo
    register_virtual_methods(klass, module_yo)
    register_methods(klass, module_yo)
    _register_callbacks(klass, module_yo)
  end

  def build_module_object(klass, parent)
    module_name = klass.attributes["name"]
    module_yo = ModuleObject.new(parent, module_name)
    @klasses_yo[module_name] = module_yo
    module_yo.docstring = read_doc(klass)
    register_virtual_methods(klass, module_yo)
    register_methods(klass, module_yo)
  end

  def read_doc(node)
    documentation = node.elements["doc"]
    documentation ? parse_gtk_doc_tags(documentation.text) : ""
  end

  def parse_gtk_doc_tags(doc)
    # Substitue #GtkSomething to Gtk::Something
    parsed = doc.gsub(/\#([A-Z]+[a-z]+)([A-Z]+.*)/, '\1::\2')
    # Substitue gtk code tag to markdown code
    if /\|\[\<\!\-\- (\n|.)* \-\->((\n|.)*)\]\|/ =~ parsed
      code = Regexp.last_match(2)
      code.gsub!(/\n/, "\n    ")
      parsed.gsub!(/\|\[\<\!\-\- (\n|.)* \-\->((\n|.)*)\]\|/, code)
    end
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

  def register_properties(klass, klass_yo)
    klass.elements.each("property") do |prop|
      name = prop.attributes["name"]
      method_name =  name.gsub(/-/,"_")
      readable = prop.attributes["readable"] || "1"
      writable = prop.attributes["writable"] || "1"
      documentation = read_doc(prop)
      type_name = prop.elements["type"] ? prop.elements["type"].attributes["name"] : ""
      type = ctypes_to_ruby(type_name)

      if readable == "1"
        rname = method_name
        rname += "?" if type == "TrueClass"
        documentation += "\n@return [#{type}] #{name}"
        method = MethodObject.new(klass_yo, rname)
        method.docstring = documentation
      end

      if writable == "1"
        wname = method_name + "="
        method = MethodObject.new(klass_yo, wname)
        method.parameters = [[method_name, nil]]
        documentation += "\n@param #{method_name} [#{type}]"
        documentation += "\n@return [#{type}] #{name}"
        method.docstring = documentation
      end
    end
  end

  def register_constant(namespace, name, value, doc)
    const = ConstantObject.new(namespace, name)
    const.value = value
    const.docstring = doc
  end

  def register_virtual_methods(klass, klass_yo)
    _register_methods(klass, klass_yo, "virtual-method")
  end

  def register_methods(klass, klass_yo)
    _register_methods(klass, klass_yo, "method")
  end

  def register_constructors(klass, klass_yo)
    _register_methods(klass, klass_yo, "constructor")
  end

  def _register_callbacks(klass, klass_yo)
    klass.elements.each("field/callback") do |m|
      _register_ruby_function(m, klass_yo, "callback")
    end
  end

  def _register_methods(klass, klass_yo, method_type)
    klass.elements.each(method_type) do |m|
      _register_ruby_function(m, klass_yo, method_type)
    end
  end

  def _register_module_function(function, module_yo)
    _register_ruby_function(function, module_yo, "method")
  end

  def _register_ruby_function(function, container, method_type)
    begin
    documentation = read_doc(function)
    parameters = []
    function.elements.each("parameters/parameter") do |p|
      infos = read_parameter_information(p)
      documentation += "\n@param #{infos[:name]} [#{infos[:type]}] #{infos[:doc]}"
      parameters << [infos[:name], nil]
    end
    ret_infos = read_return_value_information(function.elements["return-value"])
    documentation += "\n@return [#{ret_infos[:type]}] #{ret_infos[:doc]}"
    name = function.attributes["name"]
    name = rubyish_method_name(name, parameters.size, ret_infos[:type])
    method = MethodObject.new(container, name)
    method.parameters = parameters
    method.docstring = documentation
    rescue => error
      STDERR.puts "Function parsing error: #{error.message}"
    end
  end

  def rubyish_method_name(name, nb_params, return_type)
    if name =~ /^get_.*$/ && nb_params == 0
      name.gsub!(/^get_/,"")
      name += "?" if (return_type == "gboolean")
      name
    elsif name =~/^set_.*$/ && nb_params == 1
      name.gsub!(/^set_(.*$)/,'\1=')
    else
      name
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
    when /(utf8)|(gunichar)/
      "String"
    when "gboolean"
      "TrueClass"
    when "none"
      "nil"
    when "gpointer"
      "GObject" # TODO : try to confirm
    when /.*\..*/
      ctype.gsub("\.", "::")
    when "GType"
      "GLib::Type"
    else
      STDERR.puts "Ctype not handled : #{ctype}"
      "#{@module_name}::#{ctype}"
    end
    # TODO : manage :
    # va_list
    # gsf_off_t
  end
end
