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
configs = require('fnoc').configs()
_ = require('underscore')
btf = require('batchtransform')
potter = require(P('lib/potter'))

#console.log JSON.stringify configs.package
#process.exit()

Handlebars.registerHelper 'list', (items, options) ->
  out = ''
  for own key,val of items
    out += options.fn(val)
  out

marked.setOptions gfm: true, pedantic: false, sanitize: true, highlight: (code, lang) ->
  hl(code)

class Site
  constructor: (@sitePath) ->
    @_potterDir = path.join(@sitePath, 'potter')
    @_dataDir = path.join(@_potterDir, 'data')
    @_buildDir = path.join(@sitePath, 'build')
    @_articlesBuildDir = path.join(@_buildDir, 'articles')
    @_vendorBuildDir = path.join(@_buildDir, 'vendor')

    @_articleTemplateDir = path.join(@_potterDir, 'article_template')

    @_potterDataFile = path.join(@_potterDir, 'potter.json')
    @_articlesDataFile = path.join(@_dataDir, 'articles.json')
    @_pagesDataFile = path.join(@_dataDir, 'pages.json')
    @_tagsDataFile = path.join(@_dataDir, 'tags.json')

    @_articleLayoutFile = path.join(@_articleTemplateDir, 'layout.html')
    @_articleLayoutTmpl = ''
    @_articleUrlTmpl = ''
    @_articleIndexFile = path.join(@_articleTemplateDir, 'index.html')
    @_articleIndexTmpl = ''



    @_potterData = {}
    @_articlesData = {}
    @_pagesData = {}
    @_tagsData = {}

    @initialized = false

  addArticleEntry: (title, tags) ->
    #slug = S(title).dasherize().toString()
    #if slug[0] is '-' then slug = slug.replace('-', '') #replace first occurence
    slug = potter.slugify(title)

    now = new Date()

    year = dt.eval(now)['year']
    month = dt.eval(now)['month']
    articleFile = path.join('articles', year, month, slug + '.md')
    
    articleData = title: title, path: articleFile, createdAt: now.getTime(), tags: tags, published: false
    @_articlesData.articles[slug + '-' + now.toISOString()] = articleData
    articleFile


  generateSkeleton: (callback) -> #template not used yet
    rock.create @sitePath, P('resources/rocks/default'), callback


  initialize: (callback) ->
    self = @
    next flow =
      ERROR: (err) ->
        callback(err)
      loadPotterData: ->
        fs.readJSONFile self._potterDataFile, @next
      loadArticlesData: (err, data) ->
        self._potterData = data
        fs.readJSONFile self._articlesDataFile, @next
      loadTagsData: (err, data) ->
        self._articlesData = data
        fs.readJSONFile self._tagsDataFile, @next
      loadArticleTemplate: (err, data) ->
        self._tagsData = data
        fs.readFile self._articleLayoutFile, 'utf8', @next
      loadArticleIndexTemplate: (err, data) ->
        self._articleLayoutTmpl = Handlebars.compile(data)
        fs.readFile self._articleIndexFile, 'utf8', @next
      done: (err, data) ->
        self._articleIndexTmpl = Handlebars.compile(data)
        self._articleUrlTmpl = Handlebars.compile(self._potterData?.articles?.dateUrls?.format)

        self.initialized = true
        
        self._articlesData = {} if not self._articlesData?
        self._articlesData.articles = {} if not self._articlesData.articles?

        callback(null)

  publishAllArticles: (callback) ->
    self = @
    outputArticles = {}

    next flow =
      ERROR: (err) ->
        callback(err)
      buildArticleDir: ->
        bd(self._articlesBuildDir).mkdir(@next)
      deleteVendorDir: ->
        bd(self._vendorBuildDir).remove(@next)
      copyVendor: ->
        fs.copy(P('vendor'), self._vendorBuildDir, @next)
      iterateArticles: ->
        nf = @
        articleKeys = _(self._articlesData.articles).keys()
        articleFiles = _(self._articlesData.articles).pluck('path')
        articleFiles = articleFiles.map((file) -> path.join(self.sitePath, file))

        b = btf(articleFiles).transform (i, file, data, write) ->
          slug = path.basename(file, '.md')
          md = marked(data.toString())

          articleData = self._articlesData.articles[articleKeys[i]]
          md = Handlebars.compile(md)(article: articleData)

          htmlFile = ''; part = ''
          if self._potterData?.articles?.dateUrls?.enable
            part = self._articleUrlTmpl(dt.eval(new Date(article.obj.createdAt), 'date-'))
            htmlFile = path.join(self._articlesBuildDir, part, slug + '.html')
          else
            htmlFile = path.join(self._articlesBuildDir, slug + '.html')

          configs.package['bootstrap-path'] = '../vendor/bootstrap-2.0.4/themes/readable/bootstrap.min.css'
          configs.package['highlight-path'] = '../vendor/highlight.js/styles/github.css'

          html = self._articleLayoutTmpl(body: md, potter: configs.package, article: articleData)
          outputArticles[articleKeys[i]] = path: htmlFile, title: articleData.title, createdAt: articleData.createdAt
          write(htmlFile, html)
        b.error (err) -> nf.error(err)
        b.end ->
          nf.next()
      generateIndex: ->
        outputArticles = _(outputArticles).sortBy (val) -> -val.createdAt
        console.log JSON.stringify(outputArticles, null, 2)
        html = self._articleIndexTmpl(articles: outputArticles, potter: configs.package)
        fs.writeFile path.join(self._articlesBuildDir, 'index.html'), html, @next
      done: ->
        callback(null)


  saveData: (callback) ->
    self = @
    next flow =
      ERROR: (err) ->
        callback(err)
      articleFile: ->
        fs.writeFile self._articlesDataFile, JSON.stringify(self._articlesData, null, 2), @next
      tagFile: ->
        fs.writeFile self._tagsDataFile, JSON.stringify(self._tagsData, null, 2), @next
      potterFile: ->
        fs.writeFile self._potterDataFile, JSON.stringify(self._potterData, null, 2), @next
      done: ->
        callback(null)



  @create: (path) ->
    new Site(path)


module.exports.Site = Site


