testutil = require('testutil')
fs = require('fs-extra')
P = require('autoresolve')
{ContentWalker} = require(P('lib/content_walker'))
S = require('string')

TEST_DIR = ''

data = """
       <!--
       author: JP Richardson
       publish: 2012-03-04
       tags: war, history
       anything: can write anything
       -->

       The Fall of the Roman Empire
       ============================

       **Julius Ceasar** was...

       """

data2 = """
       <!--
       author: JP Richardson
       publish: 2032-03-04
       tags: economics, politics
       anything: can write anything
       -->

       # Applications of Austrian Economics

       Modern economists...

       """

data3 = """
       <!--
       author: JP Richardson
       publish: 2010-02-15
       tags: movies, books
       anything: can write anything
       -->

       # Hunger Games Review

       Katniss was...

       """


describe 'ContentWalker', ->
  beforeEach (done) ->
    TEST_DIR = testutil.createTestDir('potter')
    done()

  describe 'walk', ->
    



