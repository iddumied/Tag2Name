require 'digest'

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
      "#{ @comments }#SHA512:#{ @sha512 }\n#{ @file }"
    end
    alias inspect to_s
  end

  def initialize file
    
    @log = File.open("M3U-SHA512-Log", "a")
    @log.puts "Time: #{ Time.now }\nFile: #{ file }"

    # cd to the playlist dir
    Dir.chdir file.split("/").map { |e| e + "/" unless e == file.split("/").last }.join

    @entries = []
    @entries << Entry.new

    file = File.open(file)
    file.each_line do |line|
      line.chop!

      if line.start_with? "#SHA512:"
        sha512 = line.gsub("#SHA512:","")
        sha512 = "" unless sha.length == 128
        @entries.last.add_sha512 sha12
      
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

        @entries.last.add_file file
        @entries << Entry.new
      end
    end

    file.close
  end

  def to_s
    str = ""
    @entries.each { |e| str += e.to_s + "\n" }
    str
  end
  alias inspect to_s

end

if __FILE__ == $0
  require 'slop'

  require slop

  opts = Slop.new do
    banner "ruby #{ $0 } [options]"
    help 
    on :t, :target,  "Target file", :argument => true
  end

  opts.parse

  unless opts.target?
    puts opts
    exit
  end

  puts M3U.new(opts[:target]).to_s
end
