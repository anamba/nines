module Nines
  class Logger
    
    def initialize(io)
      @mutex = Mutex.new
      @io = io
    end
    
    def sync       ; @io.sync       ; end
    def sync=(val) ; @io.sync = val ; end
    
    def puts(*args)
      @mutex.synchronize do
        @io.puts args
      end
    end
    
    def close
      @io.close
    end
    
  end
end
