require 'java'

import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.Double
import java.net.ServerSocket

# START:class
class TemperatureTaker
  def temperature; @temperature end

  def initialize
    @temperature = 0.0 / 0.0 # NaN
  end

  def run
    @server      = ServerSocket.new 4444
    @client      = @server.accept
    stream       = @client.getInputStream
    reader       = BufferedReader.new InputStreamReader.new(stream)
    @temperature = Double.parseDouble(reader.readLine)
    @client.close
  end
end
# END:class
