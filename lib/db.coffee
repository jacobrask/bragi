"use strict"

{ Db, Connection, Server, BSONPure: { ObjectID } } = require 'mongodb'

db = new Db 'bragi-mediaserver',
       new Server 'localhost',
       Connection.DEFAULT_PORT

exports.connect = (cb = ->) ->
  db.open (err) ->
    return cb err if err?
    db.dropDatabase cb

action = (collName, errback, callback) ->
  db.collection collName, (err, coll) ->
    return errback err if err?
    callback coll

add = (collName, obj, cb) -> action collName, cb, (coll) ->
  coll.insert obj, cb

update = (collName, filter, obj, cb) -> action collName, cb, (coll) ->
  coll.update filter, { $set: obj }, { safe: true }, cb

get = (collName, filter, cb) -> action collName, cb, (coll) ->
  coll.find(filter).toArray cb

exports.getPath = (id, cb) ->
  get 'paths', { _id: new ObjectID id }, (err, arr) ->
    return cb err if err?
    cb null, arr[0].path
 
exports.getProperty = (filter, prop, cb) ->
  action 'library', cb, (coll) ->
    (o = {})[prop] = 1
    coll.find(filter, o).toArray (err, obj) ->
      cb err, obj?[0][prop]

exports.addToLibrary = (obj, cb) ->
  add 'library', obj, cb
  
exports.updateProperty = (id, obj, cb) ->
  update 'library', { _id: new ObjectID id.toString() }, obj, cb
