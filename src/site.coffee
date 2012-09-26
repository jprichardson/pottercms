P = require('autoresolve')
rock = require('rock')
path = require('path')
fs = require('fs-extra')
next = require('nextflow')
S = require('string')
dt = require('date-tokens')
parent = require('parentpath')
bd = require('batchdir')
hl = require('highlight').Highlight
marked = require('marked')
Handlebars = require('Handlebars')
potterPackage = require('../package.json')
_ = require('underscore')
batchfile = require('batchfile')
potter = require(P('lib/potter'))
util = require('util')
packageObj = require('../package')

#console.log JSON.stringify configs.package
#process.exit()

module.exports.DEFAULT_ROCK = DEFAULT_ROCK = 'personal_blog'

Handlebars.registerHelper 'list', (items, options) ->
  out = ''
  for own key,val of items
    out += options.fn(val)
  out

marked.setOptions gfm: true, pedantic: false, sanitize: true, highlight: (code, lang) ->
  hl(code)

class Site
  constructor: (@sitePath, @rockTemplate) ->
    @potterDir = path.join(@sitePath, 'potter')
    @buildDir = path.join(@sitePath, 'build')

    @articleTemplates = {}
    @potterData = {}
    @potterTemplates = {}

    @initialized = false

  addArticleEntry: (title, tags) ->
    #slug = S(title).dasherize().toString()
    #if slug[0] is '-' then slug = slug.replace('-', '') #replace first occurence
    slug = S(title).slugify()

    now = new Date()

    year = dt.eval(now)['year']
    month = dt.eval(now)['month']
    articleFile = path.join('articles', year, month, slug + '.md')
    
    articleData = title: title, path: articleFile, createdAt: now.getTime(), tags: tags, published: false
    @potterData['articles.json'].data.articles[slug + '-' + now.toISOString()] = articleData
    articleFile


  generateSkeleton: (callback) -> #template not used yet
    rock.create @sitePath, P('resources/rocks/' + @rockTemplate), callback


  initialize: (callback) ->
    self = @
    next flow =
      ERROR: (err) ->
        callback(err)
      loadPotterData: ->
        modifier = (val) -> val.data = JSON.parse(val.text); delete val.text
        loadFilesInDir path.join(self.potterDir, 'data'), modifier, @next
      loadArticleTemplateFiles: (err, res) ->
        self.potterData = res
        modifier = (val) -> val.template = Handlebars.compile(val.text); delete val.text
        loadFilesInDir path.join(self.potterDir, 'article_template'), modifier, @next
      loadPotterTemplateFiles: (err, res) ->
        nf = @
        self.articleTemplates = res
        modifier = (val) -> val.text = Handlebars.compile(val.text)(self.potterData['potter.json'])
        loadFilesInDir P('resources/templates'), modifier, (err, res) ->
          if err 
            flow.error(err)
          else
            for own file,val of res
              delete res[val]
              res[path.basename(file, '.html')] = val.text
          self.potterTemplates = res
          nf.next()
      done: ->
        self.initialized = true
        self.potterData['potter.json'].data.homepage = packageObj.homepage
        self.potterData['potter.json'].data.version = packageObj.version
        callback(null)

  publishAllArticles: (callback) ->
    self = @
    outputArticles = {}
    buildArticleDir = @buildDir#path.join(@buildDir, 'articles')
    buildVendorDir = path.join(@buildDir, 'vendor')
    potterData = @potterData['potter.json'].data

    potterData.paths = potterData.paths || {}

    #potterData.paths['bootstrap'] = 'http://netdna.bootstrapcdn.com/twitter-bootstrap/2.1.1/css/bootstrap-combined.min.css' #/vendor/bootstrap-2.0.4/themes/readable/bootstrap.min.css'
    potterData.paths['bootstrap'] = 'http://netdna.bootstrapcdn.com/bootswatch/2.1.0/spacelab/bootstrap.min.css'
    potterData.paths['highlight'] = '/vendor/highlight.js/styles/github.css'

    urlFormat = Handlebars.compile(potterData.articles.urlFormat)
    templateVals = self: null, template: @potterTemplates, potter: potterData

    next flow =
      ERROR: (err) ->
        callback(err)
      buildArticleDir: ->
        bd(buildArticleDir).mkdir(@next)
      deleteVendorDir: ->
        bd(buildVendorDir).remove(@next)
      copyVendor: ->
        fs.copy(P('vendor'), buildVendorDir, @next)
      iterateArticles: ->
        nf = @
        articles = self.potterData['articles.json'].data.articles
        articleKeys = _(articles).keys()
        articleFiles = _(articles).pluck('path')
        articleFiles = articleFiles.map((file) -> path.join(self.sitePath, file))

        b = batchfile(articleFiles).transform (i, file, data, write) ->
          slug = path.basename(file, '.md')
          md = marked(data.toString())

          articleData = articles[articleKeys[i]]
          md = Handlebars.compile(md)(article: articleData)

          urlData = slug: slug #add author in the future
          urlData = _.extend(urlData, dt.eval(new Date(articleData.createdAt), 'date-'))
          relHtmlFile = urlFormat(urlData) + '.html'
          htmlFile = path.join(buildArticleDir, relHtmlFile)

          #_article
          html = self.articleTemplates['_article.html'].template(body: md, potter: potterData)

          #layout
          self.potterTemplates.main = html
          html = self.articleTemplates['layout.html'].template(templateVals)
         
          outputArticles[articleKeys[i]] = path: '/' + relHtmlFile, title: articleData.title, createdAt: articleData.createdAt
          write(htmlFile, html)
        b.error (err) -> nf.error(err)
        b.end ->
          nf.next()
      generateIndex: ->
        outputArticles = _(outputArticles).sortBy (val) -> -val.createdAt

        #_index
        html = self.articleTemplates['_index.html'].template(articles: outputArticles, potter: potterData)

        #layout
        self.potterTemplates.main = html
        html = self.articleTemplates['layout.html'].template(templateVals)
        fs.writeFile path.join(self.buildDir, potterData.articles.indexUrl), html, @next
      done: ->
        callback(null)


  saveData: (callback) ->
    self = @
    next flow =
      ERROR: (err) ->
        callback(err)
      articleFile: ->
        obj = self.potterData['articles.json']
        fs.writeFile obj.path, JSON.stringify(obj.data, null, 2), @next
      tagFile: ->
        obj = self.potterData['tags.json']
        fs.writeFile obj.path, JSON.stringify(obj.data, null, 2), @next
      potterFile: ->
        obj = self.potterData['potter.json']
        fs.writeFile obj.path, JSON.stringify(obj.data, null, 2), @next
      done: ->
        callback(null)



  @create: (path, rock) ->
    r = rock || DEFAULT_ROCK
    new Site(path, r)


module.exports.Site = Site

## PRIVATE METHODS

loadFilesInDir = (dir, valModifier, callback) ->
  if not callback
    callback = valModifier
    valModifier = null
  fs.readdir dir, (err, files) ->
    if err
      callback(err, null)
    else
      files = files.map (f) -> path.join(dir, f)
      bf = batchfile(files).read (i, file, data, next) ->
        text = data.toString()
        fileKey = path.basename(file)
        val = text: text, path: file, key: fileKey
        if valModifier
          valModifier(val) #valModifier is function to attach any additional values to object
        next(val)
      bf.error(callback)
      bf.end (results) ->
        res = {}
        for obj in results
          res[obj.key] = obj
          delete obj.key
        callback(null, res)






