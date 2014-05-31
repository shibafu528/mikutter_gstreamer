# -*- coding: utf-8 -*-
require 'open3'

class MStreamer
    MST = File.expand_path(File.join(File.dirname(__FILE__), "mst.rb")).freeze

    def initialize
        respawn!
    end
    
    def method_missing(method, *params)
        respawn! if @mst.nil? or @mst.closed?
        formatted_args = params.map {|i|
            if i.to_s.include?(" ") then
                "\"#{i.to_s}\""
            else
                i.to_s
            end
        }.join(" ")
        @mst.puts("#{method} #{formatted_args}")
    end

    def set_stdout(&proc)
        @stdout_callback = proc
    end

    def set_stderr(&proc)
        @stderr_callback = proc
    end

    private
    def respawn!
        @mst, stdout, stderr = *Open3.popen3(RbConfig.ruby, MST)
        Thread.new(stdout) do |stdout|
            stdout.each do |line|
                /^(.+)\|(.*)/ =~ line
                @stdout_callback.call($1, $2) unless @stdout_callback.nil?
            end
        end
        Thread.new(stderr) do |stderr|
            stderr.each do |line|
                /^(.+)\|(.*)/ =~ line
                @stderr_callback.call($1, $2) unless @stderr_callback.nil?
            end
        end
    end
end

Plugin.create(:mikutter_gstreamer) do
    mst = MStreamer.new
    
    mst.set_stderr do |tag, message|
        notice "[MST:e:#{tag}] #{message}"
        Plugin.call(:gst_stderr, tag, message)
    end

    defsound :gstreamer, "GStreamer" do |filename|
        mst.play(filename, :sound)
    end

    on_gst_sample_play do |channel = :sound|
        filename = UserConfig[:notify_sound_favorited]
        mst.play(filename, channel) if !filename.nil? and File.exist?(filename)
    end

    on_gst_play do |filename, channel = :default|
        mst.play(filename, channel)
    end

    on_gst_enq do |filename, channel = :default|
        mst.enq(filename, channel)
    end

    on_gst_stop do |channel = :default|
        mst.stop(channel)
    end

    at_exit {
        mst.quit
    }
end
