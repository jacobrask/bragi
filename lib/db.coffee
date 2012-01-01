"use strict"

{ Db, Connection, Server, BSONPure: ObjectID: ObjectID } = require 'mongodb'

db = new Db 'bragi-mediaserver',
       new Server 'localhost',
       Connection.DEFAULT_PORT

exports.start = (cb) -> db.open cb

exports.add = (obj, cb) ->
  db.collection 'library', (err, collection) ->
    return cb err if err?
    collection.insert obj, cb

exports.get = (filter, cb) ->
  db.collection 'library', (err, collection) ->
    return cb err if err?
    collection.find(filter).toArray cb
