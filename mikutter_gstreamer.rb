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

        p method
        @mst.puts("#{method} #{formatted_args}") unless block_given?

        if block_given? then
            t = Thread.new do 
                so = @stdout_callback
                wait = true
                results = []
                @stdout_callback = Proc.new do |tag, message|
                    if message == "response-end" then
                        wait = false
                    else
                        results << message
                    end
                end
                while wait
                end
                @stdout_callback = so
            end
            @mst.puts("#{method} #{formatted_args}")
            t.join
        end
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
    
    mst.set_stdout do |tag, message|
        info "[MST:#{tag}] #{message}"
    end
    
    mst.set_stderr do |tag, message|
        info "[MST:e:#{tag}] #{message}"
    end

    defsound :gstreamer, "GStreamer" do |filename|
        mst.play(filename, :sound)
    end

    on_gst_play do |filename, channel = :default|
        mst.play(filename, channel)
    end

    on_gst_stop do |channel = :default|
        mst.stop(channel)
    end

    at_exit {
        mst.quit
    }
end
