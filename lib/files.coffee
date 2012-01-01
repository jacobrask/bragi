async = require 'async'
fs = require 'fs'
mime = require 'mime'
path = require 'path'

# Return non-hidden child directories of root as an array of objects.
exports.getDirectories = (root, cb) ->
  fs.readdir root, (err, files) ->
    async.filter files,
      (file, cb) ->
        return cb false if file[...1] is '.'
        fs.stat root + file, (err, stat) ->
          cb (if err? then false else stat.isDirectory())
      (res) ->
        res = res.sort()
        cb null, ({ title: file, path: root + file + '/' } for file in res)


# Return children as an object of arrays with files grouped by type.
exports.getSortedFiles = (root, cb) ->
  sortFiles = (dir, files, cb) ->
    sortedFiles = {}
    async.forEach files,
      (file, cb) ->
        fullPath = path.join dir, file
        fs.stat fullPath, (err, stat) ->
          type =
            if stat?.isDirectory() then 'folder'
            else if stat?.isFile() then mime.lookup(file).split('/')[0]
            else 'unknown'
          (sortedFiles[type]?=[]).push fullPath
          cb (if err? then err else null)
      (err) -> cb err, sortedFiles

  fs.readdir root, (err, files) ->
    return cb err if err?
    files = files.filter (file) -> file[...1] isnt '.'
    sortFiles root, files, cb
