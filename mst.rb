# -*- coding: utf-8 -*-
require 'gst'
require_relative 'gstfix'

# MStreamer is GStreamer wrapper for mikutter.
# Of course, "M" is abbr for "Miku".

class Pipeline
    def initialize
        @queue = Queue.new
        @thread = Thread.start do
            while filename = @queue.pop
                begin
                    audio = Gst::Bin.new("audiobin")
                    conv = Gst::ElementFactory.make("audioconvert")
                    audiopad = conv.get_static_pad("sink")
                    sink = Gst::ElementFactory.make("autoaudiosink")
                    audio << conv << sink
                    conv >> sink
                    audio.add_pad(Gst::GhostPad.new("sink", audiopad))

                    @pipeline = Gst::Pipeline.new("pipeline")
                    src = Gst::ElementFactory.make("filesrc")
                    src.location = filename
                    decoder = Gst::ElementFactory.make("decodebin")
                    decoder.signal_connect("pad-added") do |decoder, pad|
                        audiopad = audio.get_static_pad("sink")
                        pad.link(audiopad)
                    end

                    @pipeline << src << decoder << audio
                    src >> decoder

                    @pipeline.play
                    begin
                        running = true
                        bus = @pipeline.bus
                        
                        while running
                            message = bus.poll(Gst::MessageType::ANY, Gst::CLOCK_TIME_NONE)
                            raise "[Gst] message nil" if message.nil?
                            
                            case message.type
                            when Gst::MessageType::EOS then
                                running = false
                            when Gst::MessageType::ERROR then
                                STDERR.puts("[Gst]再生エラー: #{message.parse}")
                                running = false
                            end
                        end
                    ensure
                        @pipeline.stop
                        @pipeline = nil
                    end
                rescue => e
                    STDERR.puts(e)
                end
            end
        end
    end

    def play(filename)
        @queue.push(filename)
    end

    def stop
        @queue.clear
        unless @pipeline.nil? then
            @pipeline.stop
            @pipeline = nil
        end
    end

    def kill
        @thread.kill unless @thread.nil?
    end
end

$pipelines = {}

def play(filename, channel = "default")
    $pipelines[channel] = Pipeline.new unless $pipelines.member?(channel)
    $pipelines[channel].play(filename)
end

def stop(channel = "default")
    $pipelines[channel].stop if $pipelines.member?(channel)
end

def stop_all
    $pipelines.each_key do |key|
        stop(key)
    end
end

def status
    p $pipelines
end

def s; status end

while line = gets
    break if line.chomp == "quit"
    next if line.chomp.empty?
    cmds = line.split
    begin
        send(cmds[0], *(cmds.slice(1..-1)))
    rescue NoMethodError => e
        STDERR.puts("command not found: #{cmds[0]}")
    end
end

stop_all
$pipelines.each do |pipeline|
    pipeline.kill
end
