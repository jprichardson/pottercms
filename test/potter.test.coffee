testutil = require('testutil')
path = require('path-extra')
fs = require('fs-extra')
P = require('autoresolve')
potter = require(P('lib/potter'))

TEST_DIR = ''

describe 'PotterCMS', ->
  beforeEach (done) ->
    TEST_DIR = path.generateTestPath('test-potter')
    fs.mkdir TEST_DIR, done


