testutil = require('testutil')
fs = require('fs-extra')
P = require('autoresolve')
{Content} = require(P('lib/content'))
util = require('util')

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
       publish: 2012-03-04
       tags: war, history
       anything: can write anything
       -->

       # The Fall of the Roman Empire

       **Julius Ceasar** was...

       """

describe 'Content', ->
  beforeEach (done) ->
    TEST_DIR = testutil.createTestDir('potter')
    done()

  describe '- metadata', ->
    it 'should parse the metadata', ->
      c = Content.create(data)

      T c.metadata.author == 'JP Richardson'
      T c.metadata.publish == Date.parse('2012-03-04')
      T c.metadata.tags[0] == 'war'
      T c.metadata.tags[1] == 'history'
      T c.metadata.anything == 'can write anything'

  describe '- title', ->
    c1 = Content.create(data)
    c2 = Content.create(data2)

    T c1.title == 'The Fall of the Roman Empire'
    T c2.title == 'The Fall of the Roman Empire'

  describe '- content', ->
    c = Content.create(data)

    cnt = """
          # The Fall of the Roman Empire

          **Julius Ceasar** was...

          """
    T c.content = cnt
  



