require 'rubygems'
require 'jsduck/aggregator'
require 'jsduck/source_formatter'
require 'jsduck/class'
require 'jsduck/tree'
require 'jsduck/tree_icons'
require 'jsduck/page'
require 'json'
require 'fileutils'

module JsDuck

  # The main application logic of jsduck
  class App
    # These are basically input parameters for app
    attr_accessor :output_dir
    attr_accessor :template_dir
    attr_accessor :input_files
    attr_accessor :verbose

    def initialize
      @output_dir = nil
      @template_dir = nil
      @input_files = []
      @verbose = false
    end

    # Call this after input parameters set
    def run
      copy_template(@template_dir, @output_dir)
      classes = filter_classes(parse_files(@input_files))
      write_tree(@output_dir+"/output/tree.js", classes)
      write_pages(@output_dir+"/output", classes)
    end

    # Given array of filenames, parses all files and returns array of
    # documented items in all of those files.
    def parse_files(filenames)
      agr = Aggregator.new
      src = SourceFormatter.new(@output_dir + "/source")
      filenames.each do |fname|
        puts "Parsing #{fname} ..." if @verbose
        code = IO.read(fname)
        src_fname = src.write(code, fname)
        agr.parse(code, File.basename(src_fname))
      end
      agr.result
    end

    # Filters out class-documentations, converting them to Class objects.
    # For each other type, prints a warning message and discards it
    def filter_classes(docs)
      classes = {}
      docs.each do |d|
        if d[:tagname] == :class
          classes[d[:name]] = Class.new(d, classes)
        else
          puts "Warning: Ignoring " + d[:tagname].to_s + ": " + (d[:name] || "")
        end
      end
      classes.values
    end

    # Given array of doc-objects, generates namespace tree and writes in
    # in JSON form into a file.
    def write_tree(filename, docs)
      tree = Tree.new.create(docs)
      icons = TreeIcons.new.extract_icons(tree)
      js = "Docs.classData = " + JSON.generate( tree ) + ";"
      js += "Docs.icons = " + JSON.generate( icons ) + ";"
      File.open(filename, 'w') {|f| f.write(js) }
    end

    # Writes documentation page for each class
    def write_pages(path, docs)
      docs.each do |cls|
        filename = path + "/" + cls[:name] + ".html"
        puts "Writing to #{filename} ..." if @verbose
        File.open(filename, 'w') {|f| f.write( Page.new(cls).to_html ) }
      end
    end

    def copy_template(template_dir, dir)
      puts "Copying template files to #{dir}..." if @verbose
      if File.exists?(dir)
        FileUtils.rm_r(dir)
      end
      FileUtils.cp_r(template_dir, dir)
      FileUtils.mkdir(dir + "/output")
      FileUtils.mkdir(dir + "/source")
    end
  end

end
