Gem::Specification.new do |s|
  s.name        = "yard-gobject-introspection"
  s.version     = "0.0.1.pre"
  s.licenses    = ["GPL-2.0"]
  s.summary     = "Generate documentattion for gobject-introspection libraries."
  s.authors     = ["Ruby-GNOME2 Project Team"]
  s.files       = Dir.glob("lib/**/*") + ["COPYING.LIB", "README.md"]
  s.homepage    = "https://github.com/ruby-gnome2/yard-gobject-introspection"
  s.add_runtime_dependency "yard", "~> 0.8"
  s.add_runtime_dependency "gobject-instrospection", "~> 3.0"
end
