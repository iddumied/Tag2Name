#encoding: UTF-8
require 'taglib'
require 'optparse'

class Name
  def initialize title, artist, type
    @title, @artist, @type = title, artist, type
  end

  attr_reader :title, :artist

  def inspect
    return "#{ @artist } - #{ @title }.#{ @type }".gsub("/", "|")
  end
end

class MusicFile
  def initialize path, name
    @type = "mp3" if name.end_with? ".mp3"
    @type = "flac" if name.end_with? ".flac"
    @file = TagLib::MPEG::File.new(path + name) if name.end_with? ".mp3"
    @file = TagLib::FLAC::File.new(path + name) if name.end_with? ".flac"
    @path = path
    @old_name = name
    @new_name = read_tags
  end
  
  attr_reader :new_name

  def read_tags
    artist = @file.id3v2_tag.artist unless @file.id3v2_tag.nil?
    artist = @file.id3v1_tag.artist if !@file.id3v1_tag.nil? and  artist.nil?
    artist = @file.tag.artist       if !@file.tag.nil?       and  artist.nil?
    
    title = @file.id3v2_tag.title unless @file.id3v2_tag.nil?
    title = @file.id3v1_tag.title if !@file.id3v1_tag.nil? and title.nil?
    title = @file.tag.title       if !@file.tag.nil?       and title.nil?

    if artist.nil? or title.nil?
      return @file.name.split("/").last
    else
      return Name.new(title, artist, @type).inspect
    end
  end

  def save
    @file.close
    unless @old_name == @new_name
      File.rename(@path + @old_name, @path + @new_name)
      return true
    else
      return false
    end
  end
end

class RecursiveDir
  def initialize path, recursive = true, stats = true
    path += "/" unless path.each_char.to_a.last == "/"
    @log = File.new("Tag2NameLog", "a")
    @log.puts "="*100
    @log.puts "Path: #{ path }\n\n"

    @error = 0
    @success = 0
    @warnings = 0
    @dirs = 0
    recursive(path, recursive, stats)
  
    if stats 
      puts "\nProgressed Dirs:\t#{ @dirs }"
      puts "Progressed Files:\t#{ @error + @success + @warnings }"
      puts "\tSucesses:\t#{ @success }"
      puts "\tWarnings:\t#{ @warnings }"
      puts "\tErrors:\t\t#{ @error }"
    end

    @log.puts "\nProgressed Dirs:\t#{ @dirs }"
    @log.puts "Progressed Files:\t#{ @error + @success }"
    @log.puts "\tSucesses:\t#{ @success }"
    @log.puts "\tWarnings:\t#{ @warnings }"
    @log.puts "\tErrors:\t\t#{ @error }\n\n\n\n"
    @log.close

  end

  def recursive path, recursive = true, stats = true
    path += "/" unless path.each_char.to_a.last == "/"
    @dirs += 1

    Dir.new(path).entries.each do |entrie|
      if [".",".."].include? entrie
        #do nothingh
      elsif Dir.exists?(path + entrie) and recursive
        puts "[DD] => entering #{ path + entrie }" if $VERBOSE
        @log.puts "[DD] => entering #{ path + entrie }"
        recursive(path + entrie)

      elsif entrie.split(".").last == "mp3" or entrie.split(".").last == "flac"
        begin
          music_file = MusicFile.new(path, entrie) 
          if music_file.save
            puts "[II] #{ entrie } => #{ music_file.new_name }" if $VERBOSE
            @log.puts "[II] #{ entrie } => #{ music_file.new_name }"
            @success += 1
          else
            puts "[WW] Nothing Changed: #{ entrie }" if $VERBOSE
            @log.puts "[WW] Nothing Changed: #{ entrie }"
            @warnings += 1
          end
        rescue Exception => e
          puts "[EE] #{ e } : #{ entrie }" if $VERBOSE
          @log.puts "[EE] #{ e } : #{ entrie }" 
          @error += 1
        end
      end
    end
  end
end

if __FILE__ == $0

  options = {}
  OptionParser.new do |opts|
    opts.banner = "#{$0} [options]"
  
    opts.on("-v", "--verbose", "Run verbosely") do |v|
      options[:verbose] = v
    end
    
    opts.on("-p", "--path [PATH]", String, "Path to start") do |p|
      options[:path] = p
    end
      
    opts.on("-r", "--recursiv", "Run recursively") do |r|
      options[:recursive] = r
    end

    opts.on_tail("-h", "--help", "Show this message") do
      puts opts
      exit
    end
    
  end.parse!

  if options[:path].nil? or options.empty?
    puts "ERROR! try --help"
    exit
  end

  $VERBOSE = true if options[:verbose]
  RecursiveDir.new(options[:path], options[:recursive])
    
end
