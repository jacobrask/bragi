"use strict"

{ EventEmitter } = require 'events'
{ BSONPure: { ObjectID } } = require 'mongodb'

media = require './media'
_ = require './utils'

# Exports a "constructor" function for an object with a `database` prototype.
module.exports = (db) -> Object.create database, db: { value: db }

database =

  open: (cb) -> @db.open cb

  # Drop `library` collection, scan files in `paths` collection and add
  # results to `library` collection.
  syncPaths: (cb) ->
    @db.collection 'library', (err, coll) =>
      return cb err if err?
      coll.drop =>
        @forEach 'paths', {},
          (doc, cb) =>
            media.addPath @, doc.path, cb
          cb

  # Applies `iter` to items in `collName` matching `filter`.
  # Calls `cb` when done or on error.
  forEach: (collName, filter = {}, iter, cb) ->
    @find collName, filter, (err, cursor) ->
      return cb err if err?
      next = ->
        cursor.nextObject (err, doc) ->
          return cb err if err? or not doc?
          iter doc, next
      next()

  find: (collName, filter, cb) ->
    @db.collection collName, (err, coll) ->
      return cb err if err?
      coll.find filter, cb

  # Insert object, or update if it exists.
  upsert: (collName, obj, cb) ->
    @db.collection collName, (err, coll) ->
      obj2 = _.clone obj
      coll.findAndModify obj2,
        [['_id', 'asc']]
        { $set: obj2 }
        { safe: on, upsert: on, new: yes }
        cb

  remove: (collName, obj, cb) ->
    @db.collection collName, (err, coll) ->
      coll.remove obj, cb

  # Return true if collection has an object matching `obj`.
  has: (collName, obj, cb) ->
    @db.collection collName, (err, coll) ->
      return cb err if err?
      coll.count obj, (err, count) ->
        cb err, count > 0

  # Get a single property from object with `id`.
  getProperty: (collName, id, prop, cb) ->
    @db.collection collName, (err, coll) ->
      return cb err if err?
      (o = {})[prop] = 1
      coll.find({ _id: new ObjectID id.toString() }, o).limit(1).toArray (err, obj) ->
        cb err, obj?[0]?[prop]

  addPath: (path, cb) ->
    @upsert 'paths', { path }, cb

  getPath: (id, cb) ->
    @getProperty { _id: new ObjectID id.toString() }, 'path', cb

  removePath: (path, cb) ->
    @remove 'paths', { path }, cb

  hasPath: (path, cb) ->
    @has 'paths', { path }, cb

  # Add to library and return generated `_id`.
  addToLibrary: (obj, cb) ->
    @upsert 'library', obj, (err, doc) ->
      cb err, doc._id

  update: (collName, filter, updateAction, cb) ->
    @db.collection collName, (err, coll) ->
      return cb err if err?
      coll.update filter, updateAction, safe: true, cb

  set: (id, obj, cb) ->
    @update 'library', { _id: new ObjectID id.toString() }, { $set: obj }, cb

  push: (id, obj, cb) ->
    @update 'library', { _id: new ObjectID id.toString() }, { $push: obj }, cb
