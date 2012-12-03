module Nines
  class Logger
    
    def initialize(io)
      @mutex = Mutex.new
      @io = io
    end
    
    def sync       ; @io.sync       ; end
    def sync=(val) ; @io.sync = val ; end
    
    def puts(*args)
      @mutex.synchronize { @io.puts args }
    end
    alias_method :error, :puts
    
    def debug(*args)
      @mutex.synchronize { @io.puts args } if Nines::App.verbose
    end
    
    def close
      @io.close unless @io == STDOUT || @io == STDERR
    end
    
  end
end
