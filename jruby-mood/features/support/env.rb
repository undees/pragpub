$: << File.dirname(__FILE__) + '/../../lib'
require 'serialport'

class MoodWorld
  Emotions = %w(furious unhappy neutral happy ecstatic)

  def initialize(port)
    @port = port
  end

  def int_for(emotion)
    Emotions.index emotion
  end
end

port = SerialPort.new ENV['MOOD_HAT'], 9600, 8, 1, SerialPort::NONE
port.read_timeout = 1000
port.putc('?') until (port.getc =~ /\d/ rescue nil)
at_exit { port.close }

World { MoodWorld.new(port) }
