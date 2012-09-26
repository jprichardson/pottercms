testutil = require('testutil')
path = require('path')
fs = require('fs-extra')
P = require('autoresolve')
{Site} = require(P('lib/site'))
{Article} = require(P('lib/article'))
potter = require(P('lib/potter'))
_ = require('underscore')
S = require('string')
next = require('nextflow')

TEST_DIR = ''

describe 'Site', ->
  beforeEach (done) ->
    TEST_DIR = testutil.createTestDir('potter')
    done()

  describe '+ create()', ->
    it 'should create a Site object', ->
      site = Site.create('/tmp')
      T site.sitePath is '/tmp'


  describe '- generateSkeleton()', ->
    it 'should generate a new skeleton cms', (done) ->
      site = Site.create(TEST_DIR, 'personal_blog')
      site.generateSkeleton (err) ->
        F err?
        T fs.existsSync path.join(TEST_DIR, 'articles')
        T fs.existsSync path.join(TEST_DIR, 'pages')
        T fs.existsSync path.join(TEST_DIR, 'potter')
        done()


  describe '- initialize()', ->
    it 'should initialize the Site object with values', (done) ->
      site = Site.create(TEST_DIR, 'personal_blog')
      site.generateSkeleton (err) ->
        F err?
        site.initialize (err) ->
          F err?
          T site.initialized
          done()

  describe '- addArticleEntry()', ->
    it 'should add an article entry into the article data file with a tag array', (done) ->
      site = Site.create(TEST_DIR, 'personal_blog')
      site.generateSkeleton (err) ->
        site.initialize (err) ->
          title = 'Global Thermal Nuclear War'
          slug = S(title).dasherize().toString().replace('-', '')
          
          tags = ['politics', 'war']
          now = new Date()

          ad = site.potterData['articles.json'].data;
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
          site.potterData['articles.json'].data.a = 'a';
          site.potterData['tags.json'].data.b = 'b';
          site.potterData['potter.json'].data.c = 'c';
          site.saveData (err) ->
            F err?
            site2 = Site.create(TEST_DIR)
            site2.initialize (err) ->
              T site2.potterData['articles.json'].data.a == 'a'
              T site2.potterData['potter.json'].data.c == 'c'
              T site2.potterData['tags.json'].data.b == 'b'
              done()

  describe '- publishAllArticles()', ->
    it 'should publish all of the articles into a build dir with default options', (done) ->
      buildDir = path.join(TEST_DIR, 'build')
      articleDir = path.join(TEST_DIR, 'articles')
      buildArticleDir = path.join(buildDir, 'articles')

      t1 = 'The Fall of the Roman Empire'
      t2 = 'Applications of Austrian Economics'
      t3 = "Napoleon's Conquests"

      s1 = 'the-fall-of-the-roman-empire'
      s2 = 'applications-of-austrian-economics'
      s3 = "napoleons-conquests"

      o1 = path.join(buildArticleDir, s1 + '.html')
      o2 = path.join(buildArticleDir, s2 + '.html')
      o3 = path.join(buildArticleDir, s3 + '.html')

      data = """
              {{article.title}}
              ===============

              Blah blah blah
             """

      site = Site.create(TEST_DIR, 'personal_blog')
      site.generateSkeleton (err) ->
        site.initialize (err) ->
          next flow =
            ERROR: (err) ->
              done(err)
            createA1: -> 
              nf = @
              Article.create(site).createNew t1, ['rome', 'history'], (err, file) ->
                fs.writeFileSync(file, data)
                nf.next()
            createA2: -> 
              nf = @
              Article.create(site).createNew t2, ['economics', 'money'], (err, file) ->
                fs.writeFileSync(file, data)
                nf.next()
            createA3: -> 
              nf = @
              Article.create(site).createNew t3, ['history'], (err, file) ->
                fs.writeFileSync(file, data)
                nf.next()
            publish: ->
              F fs.existsSync(buildDir)
              site.publishAllArticles @next
            checkPaths: ->
              T fs.existsSync(o1)
              T fs.existsSync(o2)
              T fs.existsSync(o3)

              T fs.existsSync(path.join(buildDir, 'vendor'))

              T S(fs.readFileSync(o1, 'utf8').toString()).contains('<h1>' + t1)
              T S(fs.readFileSync(o2, 'utf8').toString()).contains('<h1>' + t2)

              indexFile = path.join(buildArticleDir, 'index.html')
              T fs.existsSync(indexFile)
              index = fs.readFileSync(indexFile, 'utf8')
              T S(index).contains(t1)
              T S(index).contains(t2)

              done()


          


