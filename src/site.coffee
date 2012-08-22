P = require('autoresolve')
rock = require('rock')
path = require('path')
fs = require('fs-extra')
next = require('nextflow')
S = require('string')
dt = require('date-tokens')

class Site
  constructor: (@sitePath) ->
    @_potterDir = path.join(@sitePath, 'potter')
    @_dataDir = path.join(@_potterDir, 'data')
    
    @_potterDataFile = path.join(@_potterDir, 'potter.json')
    @_articlesDataFile = path.join(@_dataDir, 'articles.json')
    @_pagesDataFile = path.join(@_dataDir, 'pages.json')
    @_tagsDataFile = path.join(@_dataDir, 'tags.json')

    @_potterData = {}
    @_articlesData = {}
    @_pagesData = {}
    @_tagsData = {}

    @initialized = false

  addArticleEntry: (title, tags) ->
    slug = S(title).dasherize().toString()
    if slug[0] is '-' then slug = slug.replace('-', '') #replace first occurence

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
      done: (err, data) ->
        self._tagsData = data

        self.initialized = true
        
        self._articlesData = {} if not self._articlesData?
        self._articlesData.articles = {} if not self._articlesData.articles?

        callback(null)


  saveData: (callback) ->



  @create: (path) ->
    new Site(path)


module.exports.Site = Site