testutil = require('testutil')
P = require('autoresolve')
fs = require('fs-extra')
path = require('path-extra')
{Article} = require(P('lib/article'))
{Site} = require(P('lib/site'))
next = require('nextflow')
dt = require('date-tokens')
S = require('string')

TEST_DIR = ''

describe 'Article', ->
  beforeEach (done) ->
    TEST_DIR = testutil.generateTestPath('test-potter')
    TEST_DIR = path.join(TEST_DIR, 'myblog')
    fs.mkdir(TEST_DIR, done)

  describe '+ createNew', ->

    it 'should create the new article', (done) ->
      site = null
      title = 'Global Thermal Nuclear Warfare'
      slug = S(title).dasherize().s.replace('-', '')

      next flow =
        ERROR: (err) ->
          done(err)
        createSite: ->
          site = Site.create(TEST_DIR)
          site.generateSkeleton (err) =>
            F err?
            site.initialize (err) =>
              F err?
              @next()
        createArticle: ->
          Article.create(site).createNew title, 'war, politics', @next
        check: ->
          T fs.existsSync path.join(TEST_DIR, 'articles', "#{dt.eval()['year']}/#{dt.eval()['month']}", slug + '.md')
          done() 


