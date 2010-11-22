# START:import
require 'java'

import java.io.BufferedReader
import java.io.InputStreamReader
import java.lang.Double
import java.net.ServerSocket
# END:import

# START:server
server      = ServerSocket.new 4444
client      = server.accept
stream      = client.getInputStream
reader      = BufferedReader.new InputStreamReader.new(stream)
temperature = Double.parseDouble(reader.readLine)
client.close

puts "Temperature is: #{temperature}"
# END:server
