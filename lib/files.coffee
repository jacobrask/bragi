"use strict"

fs = require 'fs'
mime = require 'mime'
path = require 'path'

_ = require './utils'

# Return non-hidden child directories of root as an array of objects.
getDirectories = exports.getDirectories = (root, cb) ->
  fs.readdir root, (err, files) ->
    _.async.filter files,
      (file, cb) ->
        return cb false if file[...1] is '.'
        fs.stat path.join(root, file), (err, stat) ->
          cb (if err? then false else stat.isDirectory())
      (res) ->
        res = res.sort()
        cb null, ({ title: file, path: path.join(root, file) } for file in res)


# Applies `iterator` to `root` and each of it decendant directories.
traverse = exports.traverse = (root, iterator, cb) ->
  iterator root, (err) ->
    getDirectories root, (err, dirs) ->
      _.async.forEachSeries dirs,
        (dir, cb) ->
          iterator dir.path, (err) ->
            traverse dir.path, iterator, cb
        (err) -> cb err


# Return children as an object of arrays with files grouped by type.
# Exlude files that aren't audio, video or images.
exports.getSortedFiles = (root, cb) ->
  sortFiles = (dir, files, cb) ->
    sortedFiles = {}
    _.async.forEach files,
      (file, cb) ->
        fullPath = path.join dir, file
        fs.stat fullPath, (err, stat) ->
          return cb null unless stat?.isFile()
          type = mime.lookup(file).split('/')[0]
          if type in [ 'audio', 'video', 'image' ]
            (sortedFiles[type]?=[]).push fullPath
          cb (if err? then err else null)
      (err) ->
        err = err ? new Error('No matching files') if _.isEmpty sortedFiles
        cb err, sortedFiles

  fs.readdir root, (err, files) ->
    return cb err if err?
    files = files.filter (file) -> file[...1] isnt '.'
    sortFiles root, files, cb
