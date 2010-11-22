require 'java'

import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.Double
import java.net.ServerSocket

class TemperatureTaker
  def temperature; @temperature end

  def initialize
    @temperature = 0.0 / 0.0 # NaN
  end

  # START:run
  def run
    @server = ServerSocket.new 4444

    while true do
      @client      = @server.accept
      stream       = @client.getInputStream
      reader       = BufferedReader.new InputStreamReader.new(stream)
      @temperature = Double.parseDouble(reader.readLine)
      @client.close
    end
  end
  # END:run

  # START:start
  def start
    java.lang.Thread.new(self).start
  end
  # END:start

  # START:stop
  def stop
    @client.close if @client
    @server.close if @server
  end
  # END:stop
end
