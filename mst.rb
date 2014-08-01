# -*- coding: utf-8 -*-
require 'gst'
require_relative 'gstfix'

# MStreamer is GStreamer wrapper for mikutter.
# Of course, "M" is abbr for "Miku".

class Pipeline
    def initialize(slug)
        @slug = slug

        @player = Gst::ElementFactory.make("playbin")
        @player.set_property("flags", 2)
        volume = 1.0
        @bus = @player.bus

        @queue = Queue.new
        @thread = Thread.start do
            STDERR.puts("#{@slug}|Created Pipeline")
            while filename = @queue.pop
                begin
                    if Gst.valid_uri?(filename) then
                        @player.uri = filename
                    else
                        @player.uri = Gst.filename_to_uri(filename)
                    end
                    @player.play
                    begin
                        STDERR.puts("#{@slug}|Playing #{filename}")
                        while @player.get_state(Gst::CLOCK_TIME_NONE).include?(Gst::State::PLAYING)
                            message = @bus.poll(Gst::MessageType::ANY, Gst::CLOCK_TIME_NONE)
                            case message.type
                            when Gst::MessageType::EOS
                                STDERR.puts "#{@slug}|EOS"
                                break
                            when Gst::MessageType::ERROR
                                error, debug = message.parse_error
                                STDERR.puts "#{@slug}|Debugging info: #{debug || 'none'}"
                                STDERR.puts "#{@slug}|Error: #{error.message}"
                                break
                            end
                        end
                    ensure
                        STDERR.puts("#{@slug}|Break")
                        @player.stop unless @player.get_state(Gst::CLOCK_TIME_NONE).include?(Gst::State::NULL)
                    end
                rescue => e
                    STDERR.puts("#{@slug}|#{e}")
                end
            end
        end
    end

    def play(filename)
        stop
        @queue.push(filename)
    end

    def enq(filename)
        @queue.push(filename)
    end

    def stop
        @queue.clear
        @player.stop
    end

    def next
        @player.stop
    end

    def volume=(vol)
        @player.set_property("volume", vol)
    end

    def kill
        stop
        @thread.kill unless @thread.nil?
    end
end

PipeObj = Struct.new(:command, :args)

class PipeProcess
    def initialize(slug)
        read, @write = IO.pipe
        Marshal.dump(slug, @write)
        @pid = fork do
            slug = Marshal.load(read)
            pipeline = Pipeline.new(slug)
            while obj = Marshal.load(read)
                break if obj.command.to_s == "kill"
                pipeline.send(obj.command, *obj.args)
            end
            pipeline.kill
            STDERR.puts("#{slug}|Dispose")
            read.close
            @write.close
        end
        Process.detach(@pid)
    end

    def method_missing(method, *params)
        Marshal.dump(PipeObj.new(method, params), @write)
    end
end

$pipelines = {}

def exist?(channel)
    $pipelines.member?(channel)
end

def exist_or_gen?(channel)
    $pipelines[channel] = PipeProcess.new(channel) unless $pipelines.member?(channel)
    $pipelines.member?(channel)
end

def play(filename, channel = "default")
    if filename.start_with?("http") or File.exist?(filename) then
        $pipelines[channel].play(filename) if exist_or_gen?(channel)
    else
        STDERR.puts("sys|file not found: #{filename}")
    end
end

def enq(filename, channel = "default")
    if filename.start_with?("http") or File.exist?(filename) then
        $pipelines[channel].enq(filename) if exist_or_gen?(channel)
    else
        STDERR.puts("sys|file not found: #{filename}")
    end
end

def next(channel = "default")
    $pipelines[channel].next if exist?(channel)
end

def stop(channel = "default")
    $pipelines[channel].stop if exist?(channel)
end

def stop_all
    $pipelines.each_key do |key|
        stop(key)
    end
end

def set_volume(vol, channel = "default")
    vol = vol.to_f / 100
    $pipelines[channel].volume = vol if exist_or_gen?(channel)
end

def kill(channel = "default")
    if exist?(channel) then
        $pipelines[channel].kill
        $pipelines.delete(channel)
    end
end

def kill_all
    $pipelines.each_key do |key|
        kill(key)
    end
end

STDERR.puts("sys|Welcome to MStreamer")

while line = gets
    line.chomp!
    break if line.strip == "quit" or line.strip == "q"
    next if line.empty?
    cmds = line.scan(/(".+?"|\S+)/).map do |c|
        if c[0] =~ /".+"/ then
            c[0][1..-2]
        else
            c[0]
        end
    end
    begin
        send(cmds[0], *(cmds.slice(1..-1)))
    rescue NoMethodError => e
        STDERR.puts("sys|command not found: #{cmds[0]} :: #{e}")
    rescue ArgumentError => e
        STDERR.puts("sys|invalid arguments: #{line}")
    end
end

STDERR.puts("sys|Quitting MStreamer")
kill_all
