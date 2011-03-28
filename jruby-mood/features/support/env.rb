# START:port
$: << File.dirname(__FILE__) + '/../../lib'
require 'serialport'

port = SerialPort.new ENV['MOOD_HAT'], 9600, 8, 1, SerialPort::NONE
port.read_timeout = 1000
port.putc('?') until (port.getc =~ /\d/ rescue nil)
at_exit { port.close }
# END:port

# START:world
class MoodWorld
  # END:world

  # START:world
  def initialize(port)
    @port = port
  end

  # ... more methods here ...
  # END:world

  # START:emotions
  Emotions = %w(furious unhappy neutral happy ecstatic)

  def int_for(emotion)
    Emotions.index emotion
  end
  # END:emotions

  # START:world
end

World { MoodWorld.new(port) }
# END:world
