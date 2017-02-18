#!/usr/bin/env ruby

require "rexml/document"

gir_path = "/usr/share/gir-1.0"

def print_help
puts %q(
usage:
  overview_of_gir_file.rb pattern [type] [expand]

  pattern is for example Atk for the file Atk-1.0.gir

)
end

if ARGV.size < 1 && ARGV.size > 3
  STDERR.puts "Bad number of arguments"
  print_help
  exit 1
end

expand = false
type = nil
expand = ARGV.include?("expand")

ARGV[1..2].each do |arg|
  type = arg unless arg == "expand"
end

file_name = ARGV[0]

girs_files = Dir.glob("#{gir_path}/#{file_name}-?.*gir")
gir_file = girs_files.last

if gir_file.nil?
  STDERR.puts "#{ARGV[0]} does not match any gir files"
  print_help
  exit 1
end

file = File.new(gir_file)
gir_document = REXML::Document.new file

element_names = {}
gir_document.elements.each("repository/namespace/*") do |element|
  attr_name = element.attributes["name"]

  if element_names[element.name].class == Array
    element_names[element.name] << attr_name
  else
    element_names[element.name] = [attr_name]
  end
end

def display_information(name, elements, expand)
  puts name
  if expand
    elements.each do |e|
      puts "\t* #{e}"
    end
  end
end

element_names.each do |name, elements|
  if type
    display_information(name, elements, expand) if name == type
  else
    display_information(name, elements, expand)
  end
end
