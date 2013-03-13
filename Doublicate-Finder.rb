require './Dir.rb'
require 'digest'

class ArrayEntryHash
  def initialize; @database = { }; end

  def []= index, value
    @database[index] = Array.new if @database[index].nil?
    @database[index] << value
  end
  alias store []=

  def [] index; @database[index]; end
  attr_reader :database
end


##
# implementation of an Database which saves the sha512 sum for files
# and can handel doublicates
#
class Database
  def initialize path, log, blocksize = 1024**2 * 100 
    @log = log
    @database = ArrayEntryHash.new
    @blocksize = blocksize

    begin
      if File.directory? path
        Dir.recursive(path) do |file|
          begin
            @database.store sha512sum(file), file
            @log.puts "[II] database entry: #{ file }"
            puts "[II] database entry: #{ file }" if $VERBOSE
          rescue Exception => e
            @log.puts "[EE] #{ e } by adding entry to Database"
            puts "[EE] #{ e } by adding entry to Database" if $VERBOSE
          end
        end
     
      elsif File.exists? path
        File.open(path).each_line do |line|
          line.chop!
          @database.store line[0,128], line[128, line.length - 128]
        end
        @log.puts "[II] Database readed #{ @database.database.length } entries found in: #{ path }"
        puts "[II] Database readed #{ @database.database.length } entries found in: #{ path }" if $VERBOSE
     
      else
        @log.puts "[EE] no such fil or directory: #{ path }"
        puts "[EE] no such fil or directory: #{ path }" if $VERBOSE
      end
    rescue Exception => e
      @log.puts "[EE] #{ e } while creating Database from #{ path }"
      puts "[EE] #{ e } while creating Database from #{ path }" if $VERBOSE
      @log.close
      raise e
    end
  end

  def database; @database.database; end

  def [] index; @database[index]; end
  def []= index, var; @database[index] = var; end

  def save fname
    begin
      file = File.new(fname, "w")
      @database.database.each { |k, a| a.each { |v| file.puts(k + v) } }
      file.close
      @log.puts "[II] #{ @database.database.length } Database enries writtten to #{ fname }"
      puts "[II] #{ @database.database.length } Database enries writtten to #{ fname }" if $VERBOSE
    rescue Exception => e
      @log.puts "[EE] #{ e } while saving Database to file #{ fname }"
      puts "[EE] #{ e } while saving Database to file #{ fname }" if $VERBOSE
    end
  end

  private

  def sha512sum file
    File.open(file, 'rb') do |io|
      dig = Digest::SHA512.new
      while (buf = io.read(@blocksize))
        dig.update(buf)
      end
      dig.hexdigest
    end
  end

end

class DoublicateFinder
  def initialize path, dir = nil
    @log = File.open("DoublicateFinderLog", "a")
    @log.puts "\n\n" + "="*100
    @log.puts "Time: #{ Time.now }\nPath: #{ path }\nSpecial Doublicates Dir: #{ dir }"

    @database = Database.new path, @log
    @doublicates = { }
    @removes = { }

    @database.database.each do |sha512sum, ary|
      next if ary.length <= 1
      @doublicates[sha512sum] = ary
      
      @log.puts "[II] found following doublicates:"
      ary.each { |file| @log.puts "[II]\t#{ file }" }
      if $VERBOSE
        puts "[II] found following doublicates:"
        ary.each { |file| puts "[II]\t#{ file }" }
      end

      allindir = true
      ary.each { |file| allindir = false unless file.include? dir }
      next if allindir == true
    
      unless dir.nil?
        ary.each do |file|
          if file.include? dir
            @removes[sha512sum] = Array.new if @removes[sha512sum].nil?
            @removes[sha512sum] << file 
            @log.puts "[II] found Doublicate in #{ dir }: #{ file }"
            puts "[II] found Doublicate in #{ dir }: #{ file }" if $VERBOSE
          end
        end
      end
    end

  end
  attr_reader :database

  def print_removes; @removes.each { |sha512sum, ary| ary.each { |file| puts file } }; end
  
  def print_doublicates
    @doublicates.each do |sha512sum, array|
      puts "="*100
      array.each { |file| puts file }
    end
    puts "="*100
  end

  def remove
    @removes.each do |sha512sum, ary|
      ary.each do |file|
        begin
          File.delete(file)
          @doublicates[sha512sum].delete(file)
          @database[sha512sum].delete(file)
          @log.puts "[II] removed #{ file }"
          puts "[II] removed #{ file }" if $VERBOSE
        rescue Exception => e
          @log.puts "[EE] #{ e } while removing #{ file }"
          puts "[EE] #{ e } while removing #{ file }" if $VERBOSE
        end
      end
    end
    @removes = { }
  end

  def select
    menu = "(q)\tquit selection\n(n)\tnext Doublicates"

    @doublicates.each do |sha512sum, ary|
      while true
        break if ary.length <= 1
        puts menu
        ary.each_with_index { |file, i| puts "(#{ i })\t#{ file }" }
        print "Eingabe: "
        eingabe = gets.chop!
        if eingabe == "q"
          return true
        elsif eingabe == "n"
          break;
        elsif /^[0-9]+$/ =~ eingabe
          eingabe = eingabe.to_i
          if eingabe < ary.length
            @removes[sha512sum] = Array.new if @removes[sha512sum].nil?
            @removes[sha512sum] << ary[eingabe]
            @log.puts "[II] added to removes #{ ary[eingabe] }"
            ary.delete_at(eingabe)
          end
        end
      end
    end
  end
  
  def write_removes name
    begin
      file = File.new(name, "w")
      @removes.each { |k, a| a.each { |v| file.puts(k + v) } }
      file.close
      @log.puts "[II] to-remove-list written to file: #{ name }"
      puts "[II] to-remove-list written to file: #{ name }" if $VERBOSE
    rescue Exception => e
      @log.puts "[EE] #{ e } while writting to-remove-list: #{ name }"
      puts "[EE] #{ e } while writting to-remove-list: #{ name }" if $VERBOSE
    end
  end

  def load_removes name
    begin
      File.open(name).each_line do |line|
        line.chop!

        sha512sum, file = line[0,128], line[128, line.length - 128]
        @removes[sha512sum] = Array.new if @removes[sha512sum].nil?
        @doublicates[sha512sum].delete(file)
        @removes[sha512sum].delete(file)
        @removes[sha512sum] << file
        @log.puts "[II] loaded remove #{ file }"
        puts "[II] loaded remove #{ file }" if $VERBOSE
      end
    rescue Exception => e
      @log.puts "[EE] #{ e } while loading to-remove-list: #{ name }"
      puts "[EE] #{ e } while loading to-remove-list: #{ name }" if $VERBOSE
    end
  end
end

if __FILE__ == $0
  require 'slop'
  opts = Slop.new do
    banner "ruby #{ $0 } [options]"
    help 
    on :v,    :verbose,             "Be Verbose"
    on :p,    :print,               "Print Output (can be used without --remove to show changes)"
    on "-s",  "--database-source",  "Path to Database Source dir, absolute or relative to target",  :argument => true
    on :d,    :database,            "Database file",                                                :argument => true
    on "-c",  "--create-database",  "Create the database from database-source" 
    on "-t",  "--database-target",  "File to save the Database",                                    :argument => true
    on        "--remove",           "remove Doublicated Files"
    on        "--remove-dir",       "Directory from wich doublicates should be removed",            :argument => true
    on "-i",  "--interactive",      "use interactive mode"
    on        "--database-only",   "Only create the Database and exit"
  end

  opts.parse
  $VERBOSE = true if opts.verbose?


  if (opts["database-source"].nil? and opts["database"].nil?) or
        (opts["create-database"] != nil and opts["database-target"].nil?) or
          (opts["database-source"] != nil and opts["database"] != nil)

    puts opts
    exit
  end

  unless opts["database-only"].nil?
    if opts["database-source"].nil? or opts["create-database"].nil? or opts["database-target"].nil?
      puts opts
      exit
    end

    log = File.open("DoublicateFinderLog", "a")
    log.puts "\n\n" + "="*100
    log.puts "Time: #{ Time.now }\nCreate Database: #{ opts["database-target"] } form #{ opts["database-source"] }"

    database = Database.new opts["database-source"], log
    database.save opts["database-target"]
    exit
  end

  double = DoublicateFinder.new opts["database"], opts["remove-dir"] unless opts["database"].nil?
  double = DoublicateFinder.new opts["database-source"], opts["remove-dir"] unless opts["database-source"].nil?

  if opts.interactive?
    ARGV.clear
    menu = "(q)\tQuit Programm\n(p)\tPrint to-remove-list\n(d)\tPrint Doublicates\n(s)\tSelect Doublicates to remove\n"
    menu += "(w)\tWrite to-remove-list\n(l)\tLoad to-remove-list\n(r)\tRemove all files in to-remove-list\nEingabe: "

    while true
      print menu
      eingabe = gets.chop
      
      case eingabe
        when "q" then exit
        when "p" then double.print_removes
        when "d" then double.print_doublicates
        when "s" then double.select
        when "r" 
          double.remove
          double.database.save opts["database-target"] unless opts["create-database"].nil?
        when "w"
          print "Filename: "
          name = gets.chop
          double.write_removes name
        when "l"
          print "Filename: "
          name = gets.chop
          double.load_removes name
      end
    end
  end

  double.remove if opts.remove?
  double.print_removes if opts.print?
  double.database.save opts["database-target"] unless opts["create-database"].nil?
end
