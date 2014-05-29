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
                                STDOUT.puts "#{@slug}|Debugging info: #{debug || 'none'}"
                                STDOUT.puts "#{@slug}|Error: #{error.message}"
                                break
                            end
                        end
                    ensure
                        STDERR.puts("#{@slug}|Break")
                        @player.stop unless @player.get_state(Gst::CLOCK_TIME_NONE).include?(Gst::State::NULL)
                    end
                rescue => e
                    STDERR.puts(e)
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

    def kill
        stop
        @thread.kill unless @thread.nil?
    end
end

$pipelines = {}

def play(filename, channel = "default")
    if File.exist?(filename) then
        $pipelines[channel] = Pipeline.new(channel) unless $pipelines.member?(channel)
        $pipelines[channel].play(filename)
    else
        STDERR.puts("file not found: #{filename}")
    end
end

def enq(filename, channel = "default")
    if File.exist?(filename) then
        $pipelines[channel] = Pipeline.new(channel) unless $pipelines.member?(channel)
        $pipelines[channel].enq(filename)
    else
        STDERR.puts("file not found: #{filename}")
    end
end

def next(channel = "default")
    $pipelines[channel].next if $pipelines.member?(channel)
end

def stop(channel = "default")
    $pipelines[channel].stop if $pipelines.member?(channel)
end

def stop_all
    $pipelines.each_key do |key|
        stop(key)
    end
end

def kill(channel = "default")
    if $pipelines.member?(channel) then
        $pipelines[channel].kill
        $pipelines.delete(channel)
    end
end

def kill_all
    $pipelines.each_key do |key|
        kill(key)
    end
end

def status
    puts "status|#{$pipelines}"
    puts "status|response-end"
end

def s; status end

STDERR.puts("sys|Welcome to MStreamer")

while line = gets
    line.chomp!
    break if line.strip == "quit" or line.strip == "q"
    next if line.empty?
    cmds = line.split
    begin
        send(cmds[0], *(cmds.slice(1..-1)))
    rescue NoMethodError => e
        STDERR.puts("command not found: #{cmds[0]} :: #{e}")
    rescue ArgumentError => e
        STDERR.puts("invalid arguments: #{line}")
    end
end

STDERR.puts("sys|Quitting MStreamer")
kill_all
