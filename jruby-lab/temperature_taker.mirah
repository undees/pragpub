import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.Double
import java.net.ServerSocket

class TemperatureTaker
  implements Runnable

  def temperature; @temperature end

  def initialize
    @temperature = 0.0 / 0.0 # NaN
  end

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

  def start
    Thread.new(self).start
  end

  def stop
    @client.close if @client
    @server.close if @server
  end
end
