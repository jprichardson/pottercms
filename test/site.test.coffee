testutil = require('testutil')
path = require('path')
fs = require('fs-extra')
P = require('autoresolve')
{Site} = require(P('lib/site'))
_ = require('underscore')
S = require('string')

TEST_DIR = ''

describe 'Site', ->
  beforeEach (done) ->
    TEST_DIR = testutil.generateTestPath('test-potter')
    TEST_DIR = path.join(TEST_DIR, 'mycmsblog')
    fs.mkdir(TEST_DIR, done)

  describe '+ create()', ->
    it 'should create a Site object', ->
      site = Site.create('/tmp')
      T site.sitePath is '/tmp'


  describe '- generateSkeleton()', ->
    it 'should generate a new skeleton cms', (done) ->
      site = Site.create(TEST_DIR)
      site.generateSkeleton (err) ->
        F err?
        T fs.existsSync path.join(TEST_DIR, 'articles')
        T fs.existsSync path.join(TEST_DIR, 'pages')
        T fs.existsSync path.join(TEST_DIR, 'potter')
        done()


  describe '- initialize()', ->
    it 'should initialize the Site object with values', (done) ->
      site = Site.create(TEST_DIR)
      site.generateSkeleton (err) ->
        F err?
        site.initialize (err) ->
          F err?
          T site.initialized
          done()

  describe '- addArticleEntry()', ->
    it 'should add an article entry into the article data file with a tag array', (done) ->
      site = Site.create(TEST_DIR)
      site.generateSkeleton (err) ->
        site.initialize (err) ->
          title = 'Global Thermal Nuclear War'
          slug = S(title).dasherize().toString().replace('-', '')
          
          tags = ['politics', 'war']
          now = new Date()

          ad = site._articlesData;
          T _(ad.articles).size() is 0
          articlePath = site.addArticleEntry(title, tags)

          T S(articlePath).contains(now.getFullYear())
          T S(articlePath).contains((now.getMonth() + 1).toString())
          T S(articlePath).contains(slug)
          T _(ad.articles).size() is 1

          done()

  describe '- saveData()', ->
    it 'should save article, tag, and potter data', (done) ->
      site = Site.create(TEST_DIR)
      site.generateSkeleton (err) ->
        site.initialize (err) ->
          site._articlesData.a = 'a';
          site._tagsData.b = 'b';
          site._potterData.c = 'c';
          site.saveData (err) ->
            F err?
            site2 = Site.create(TEST_DIR)
            site2.initialize (err) ->
              T site2._articlesData.a is 'a'
              T site2._potterData.c is 'c'
              T site2._tagsData.b is 'b'
              done()


          


