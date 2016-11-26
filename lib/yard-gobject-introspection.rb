require "yard"

class MyModuleHandler < YARD::Handlers::Ruby::Base
  handles :module

  def process
    puts "Handling a module named #{statement[0].source}"
  end
end
