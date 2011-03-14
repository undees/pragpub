require 'java'
require 'RXTXcomm.jar'

java_import('gnu.io.CommPortIdentifier')
java_import('gnu.io.SerialPort') { 'JSerialPort' }

class SerialPort
  attr_accessor :read_timeout

  %w(NONE SPACE MARK EVEN ODD).each do |parity|
    const_set parity, JSerialPort.const_get("PARITY_#{parity}")
  end

  def initialize name, baud, data, stop, parity
    port_id = CommPortIdentifier.get_port_identifier name
    data    = JSerialPort.const_get "DATABITS_#{data}"
    stop    = JSerialPort.const_get "STOPBITS_#{stop}"

    @port = port_id.open 'JRuby', 500
    @port.set_serial_port_params baud, data, stop, parity

    @in  = @port.input_stream
    @out = @port.output_stream
  end

  def putc(char)
    @out.write char[0, 1].to_java_bytes
  end

  def getc
    if @read_timeout
      deadline = Time.now + @read_timeout / 1000.0
      sleep 0.1 until @in.available > 0 || Time.now > deadline
    end

    @in.to_io.read(@in.available)[-1, 1] || ''
  end

  def close
    @port.close
  end
end
