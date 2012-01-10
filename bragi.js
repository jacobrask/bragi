#!/usr/bin/env node

if (process.env.NODE_ENV == null || process.env.NODE_ENV === undefined) {
  process.env.NODE_ENV = 'production';
}

require('coffee-script');
require('./lib/index');
