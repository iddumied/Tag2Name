require 'digest'
require './Dir.rb'
require './SHA512-Database.rb'

##
# Just a little script to add SHA512 summs to a playlist, and restore
# pathes with it
#
class M3U
  
  class Entry

    def initialize
      @comments, @sha512, @file = "", "", ""
    end
    attr_reader :comments, :sha512, :file

    def add_comment str
      @comments += str + "\n"
    end

    def add_sha512 sha512
      @sha512 = sha512
    end

    def add_file file
      @file = file
    end

    def to_s
      str =  "#{ @comments }"
      str += "#SHA512:#{ @sha512 }" unless @sha512 == ""
      str += "\n" if @sha512 != "" and @file != ""
      str += "#{ @file }" unless @file == ""
      str
    end
    alias inspect to_s
  end


  def initialize file

    @file = file
    
    @log = File.open("M3U-SHA512-Log", "a")
    @log.puts "\n\n" + "="*100
    @log.puts "Time: #{ Time.now }\nFile: #{ file }"

    # cd to the playlist dir
    Dir.chdir file.split("/").map { |e| e + "/" unless e == file.split("/").last }.join if file.include? "/"

    @entries = []
    @entries << Entry.new

    file = File.open(file)
    file.each_line do |line|
      line.chop!

      if line.start_with? "#SHA512:"
        sha512 = line.gsub("#SHA512:","")
        sha512 = "" unless sha512.length == 128
        @entries.last.add_sha512 sha512
      
      elsif line.start_with? "#"
        @entries.last.add_comment line

      else
        begin
          if File.exists? line
            sha512 = Digest::SHA512.hexdigest(File.read(line))
            
            if @entries.last.sha512 != "" && @entries.last.sha512 != sha512
              @log.puts "[WW] different SHA512 sum found in file: #{ line }"
              puts "[WW] different SHA512 sum found in file: #{ line }" if $VERBOSE
            end

            @entries.last.add_sha512 sha512
          else
            @log.puts "[WW] file not found: #{ line }"
            puts "[WW] file not found: #{ line }" if $VERBOSE
          end
        rescue Exception => e
          @log.puts "[EE] #{ e }: #{ line }"
          puts "[EE] #{ e }: #{ line }" if $VERBOSE
        end

        @log.puts "[II] m3u entry: #{ line }"
        puts "[II] m3u entry: #{ line }" if $VERBOSE

        @entries.last.add_file line
        @entries << Entry.new
      end
    end

    file.close
  end

  ##
  # restores an m3u file based on the SHA512 SUMs
  #
  def restore path_to_database
    path_to_database.sub Dir.pwd, ""
    path_to_database.sub "/", ""
    
    @database ||= Database.new(path_to_database, @log)
    @entries.each do |entry|
      unless @database[entry.sha512].nil?
        oldfile = entry.file
        entry.add_file @database[entry.sha512]
        @log.puts "[II] restored #{ oldfile } => #{ entry.file }"
        puts "[II] restored #{ oldfile } => #{ entry.file }" if $VERBOSE
      else
        @log.puts "[WW] couldn't find and restore #{ entry.file } in Database"
        puts "[WW] couldn't find and restore #{ entry.file } in Database" if $VERBOSE
      end
    end
  end

  def save_database name
    unless @database.nil?
      @database.save name
    else
      @log.puts "[EE] couldn't save Database, Database didn't exists"
      puts "[EE] couldn't save Database, Database didn't exists" if $VERBOSE
    end      
  end


  def to_s
    str = ""
    @entries.each { |e| str += e.to_s + "\n" }
    str.chop
  end
  alias inspect to_s

  def save
    begin
      file = File.new(@file, "w")
      file.write to_s
      file.close

      @log.puts "[II] SHA512 SUMs written to file #{ @file }"
      puts "[II] SHA512 SUMs written to file #{ @file }" if $VERBOSE

    rescue Exception => e
      @log.puts "[EE] #{ e }: while writting file#{ @file }"
      puts "[EE] #{ e }: while writting file#{ @file }" if $VERBOSE
    end
  end

end

if __FILE__ == $0
  require 'slop'

  opts = Slop.new do
    banner "ruby #{ $0 } [options]"
    help 
    on :t, :target,  "Target file", :argument => true
    on :v, :verbose, "Be Verbose"
    on :c, :create,  "Create SHA512 SUMs"
    on :p, :print,   "Print Output (can be used without create to show changes)"
    on "--database-source", "Path to Database Source dir, absolute or relative to target", :argument => true
    on :database, "Database file", :argument => true
    on "--create-database", "Create the database from database-source" 
    on "--database-target", "File to save the Database", :argument => true
    on "--restore", "restore m3u file using database"
  end

  opts.parse
  $VERBOSE = true if opts.verbose?


  unless opts.target?
    puts opts
    exit
  end
  
  m3u = M3U.new opts[:target]

  if opts.restore?
    if (opts["database-source"].nil? and opts["database"].nil?) or
          (opts["create-database"] != nil and opts["database-target"].nil?)
      puts opts
      exit
    end

    m3u.restore opts["database"] unless opts["database"].nil?
    m3u.restore opts["database-source"] unless opts["database-source"].nil?

    m3u.save_database opts["database-target"] unless opts["create-database"].nil?
  end

  m3u.save if opts.create?
  puts m3u.to_s if opts.print?
end
