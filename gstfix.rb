# -*- coding: utf-8 -*-
require "gst"

=begin
Ruby/GStreamer 2.2.0 を ruby 2.1.0 上で使用する際に、
Gst.init で例外がスローされ使用することができなくなる不具合を修正します
パッチはすでにGithub上でマージされていますので、
次期バージョン以降はこのモンキーパッチを使用する必要は無くなると期待されます

パッチ引用元:
https://github.com/ruby-gnome2/ruby-gnome2/issues/232
https://github.com/ruby-gnome2/ruby-gnome2/commit/29dd9ccdf06b2fe7d9f5cf6ace886bb89adcebf2
=end

module Gst
    class Loader
        def call_init_function(repository, namespace)
            init_check = repository.find(namespace, "init_check")
            arguments = [
                1 + @init_arguments.size,
                [$0] + @init_arguments,
            ]
            succeeded, argc, argv, error = init_check.invoke(:arguments => arguments)
            succeeded, argv, error = init_check.invoke(:arguments => arguments)
            @init_arguments.replace(argv[1..-1])
            raise error unless succeeded
        end
    end
end
