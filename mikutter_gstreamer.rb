# -*- coding: utf-8 -*-
require 'open3'

class MStreamer
    def initialize
        respawn!
    end

    def query(command, args)
        respawn! if @mst.nil? or @mst.closed?
        formatted_args = args.map {|i|
            i.to_s
            "\"#{i.to_s}\"" if i.to_s.include?(" ")
        }.join(" ")
        @mst.puts("#{command} #{formatted_args}")
    end
    
    def method_missing(method, *params)
        query
    end
    
    private
    def respawn!
        @mst = Open3.popen3("mst.rb", "r+").tap do |mst|
            mst.close_on_exec = true
            mst.autoclose = true
            mst.sync = true
        end
    end
end

Plugin.create(:mikutter_gstreamer) do
    mst = MStreamer.new

    defsound :gstreamer, "GStreamer" do |filename|
        mst.play(filename)
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
