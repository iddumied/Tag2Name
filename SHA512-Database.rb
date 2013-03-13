require './Dir.rb'
require 'digest'

##
# implementation of an Database which saves the sha512 sum for files
#
class Database
  def initialize path, log, blocksize = 1024**2 * 100 
    @log = log
    @database = { }
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
        @log.puts "[II] Database readed #{ @database.length } entries found in: #{ path }"
        puts "[II] Database readed #{ @database.length } entries found in: #{ path }" if $VERBOSE
     
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

  def [] index; @database[index]; end
  def []= index, var; @database[index] = var; end

  def save fname
    begin
      file = File.new(fname, "w")
      @database.each { |k, v| file.puts(k + v) }
      file.close
      @log.puts "[II] #{ @database.length } Database enries writtten to #{ fname }"
      puts "[II] #{ @database.length } Database enries writtten to #{ fname }" if $VERBOSE
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

if __FILE__ == $0
  require 'slop'

  opts = Slop.new do
    banner "ruby #{ $0 } [options]"
    help 
    on :s, :source,  "Source file", :argument => true
    on :t, :target,  "Target file", :argument => true
    on :v, :verbose, "Be Verbose"
  end

  opts.parse
  $VERBOSE = true if opts.verbose?

  unless opts.target? and opts.source?
    puts opts
    exit
  end
  
  log = File.open "DatabaseLog", "a"
  log.puts "\n\n" + "="*100
  log.puts "Time: #{ Time.now }\n\n"
  Database.new(opts[:source], log).save opts[:target]

end
