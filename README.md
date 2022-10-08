# yard-gobject-instropection

yard plugin for building documentation of libraries based on GObject-Intropection.

## Requirements

* [YARD](http://yardoc.org/index.html)
* Ruby/GObject-Introspection in [Ruby-GNOME](https://github.com/ruby-gnome/ruby-gnome)
* [GObject Introspection](http://live.gnome.org/GObjectIntrospection)

## Try it

    git clone https://github.com/ruby-gnome2/yard-gobject-introspection
    cd yard-gobject-introspection
    yard doc --load lib/yard-gobject-introspection.rb ~/.gem/ruby/2.x.x/gems/gtk3-3.x.x/lib/gtk3.rb
    firefox doc/index.html

## License

Copyright (c) 2016 Ruby-GNOME Project Team

This program is free software. You can distribute/modify this program
under the terms of the GNU LESSER GENERAL PUBLIC LICENSE Version 2.1.

## Project Website

* https://github.com/ruby-gnome/ruby-gnome
* ruby-gnome2.osdn.jp/
