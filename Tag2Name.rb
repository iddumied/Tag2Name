require 'taglib'
require 'optparse'

class Name
  def initialize track, title, artist, album
    @track, @title, @artist, @album = track, title, artist, album
  end

  attr_reader :track, :artist, :album

  def inspect
    return "#{sprntf("%02d", @track)} #{@title} - #{@artist} - #{@album}.mp3"
  end
end

class MusicFile
  def initialize path, name
    @file = TagLib::MPEG::File.new(path + name)
    @path = path
    @old_name = name
    @new_name = read_tags
  end
  
  attr_reader :new_name

  def read_tags
    artist = @file.id3v2_tag.artist
    artist = @file.id3v1_tag.artist if artist.nil?
    
    title = @file.id3v2_tag.title
    title = @file.id3v1_tag.title if title.nil?

    track = @file.id3v2_tag.track
    track = @file.id3v1_tag.track if track.nil?

    album = @file.id3v2_tag.album
    album = @file.id3v1_tag.album if album.nil?

    if artist.nil? or title.nil? or track.nil? or album.nil?
      return @file.name.split("/").last
    else
      return Name.new(track, title, artist, album).inspect
    end
  end

  def save
    @file.cose
    system("mv #{@path + @old_name} #{@path + @new_name}")
  end
end

class RecursiveDir
  def initialize path, recursive = true
    path += "/" unless path.each_char.to_a.last == "/"

    Dir.new(path).entries.each do |entrie|
      if [".",".."].include? entrie
        #do nothingh
      elsif Dir.exists?(path + entrie) and recursive
        puts "=> entering #{path + entrie}" if $VERBOSE
        RecursiveDir.new(path + entrie)
      elsif entrie.split(".").last == "mp3"
        music_file = MusicFile.new(path, entrie) 
        music_file.save
        puts "#{entrie} => #{music_file.new_name}" if $VERBOSE
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

    if options[:path].nil? or ARGV.empty?
      puts opts
      exit
    end
  end.parse!

  $VERBOSE = true if options[:verbose]
  RecursiveDir.new(options[:path], options[:recursive])
    
end
