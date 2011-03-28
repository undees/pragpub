# START:imports
require 'java'
require 'RXTXcomm.jar'

java_import('gnu.io.CommPortIdentifier')
java_import('gnu.io.SerialPort') { 'JSerialPort' }
# END:imports

# START:port
class SerialPort
  attr_accessor :read_timeout

  NONE = JSerialPort::PARITY_NONE

  # ... methods go here ...
  # END:port

  # START:init
  def initialize name, baud, data, stop, parity
    port_id = CommPortIdentifier.get_port_identifier name
    data    = JSerialPort.const_get "DATABITS_#{data}"
    stop    = JSerialPort.const_get "STOPBITS_#{stop}"

    @port = port_id.open 'JRuby', 500
    @port.set_serial_port_params baud, data, stop, parity

    @in  = @port.input_stream
    @out = @port.output_stream
  end

  def close
    @port.close
  end
  # END:init

  # START:putc
  def putc(char)
    @out.write char[0, 1].to_java_bytes
  end
  # END:putc

  # START:getc
  def getc
    if @read_timeout
      deadline = Time.now + @read_timeout / 1000.0
      sleep 0.1 until @in.available > 0 || Time.now > deadline
    end

    @in.to_io.read(@in.available)[-1, 1] || ''
  end
  # END:getc

  # START:port
end
# END:port
