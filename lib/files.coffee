async = require 'async'
fs = require 'fs'

exports.getFiles = (root, cb) ->
  fs.readdir root, (err, files) ->
    async.filter files,
      (file, cb) ->
        return cb false if file[...1] is '.'
        fs.stat root + file, (err, stat) ->
          cb (if err? then false else stat.isDirectory())
      (res) ->
        res = res.sort()
        cb null, ({ title: file, path: root + file + '/' } for file in res)
