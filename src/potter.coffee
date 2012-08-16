rock = require('rock')
S = require('string')
next = require('nextflow')
util = require('util')
fs = require('fs-extra')
path = require('path-extra')
Handlebars = require('handlebars')
{TriggerFlow} = require('triggerflow')
marked = require('marked')
configs = require('fnoc').configs()
P = require('autoresolve')
hl = require('highlight').Highlight
less = require('less')
dt = require('date-tokens')
_ = require('underscore')

marked.setOptions
  gfm: true,
  pedantic: false,
  sanitize: true,
  highlight: (code, lang) ->
    hl(code)




newSite = (path, callback) ->
  rock.create(path, '/Users/jprichardson/Dropbox/Projects/Personal/rocks/rock-potter', callback)

newArticle = (title, tags, callback) ->
  urlSlug = S(title).dasherize().toString()
  if urlSlug[0] is '-' then urlSlug = urlSlug.replace('-', '') #replace first occurence

  tagArray = []
  if tags?
    tagArray = tags.split(',')

  now = new Date()
  year = now.getFullYear()
  month = ('0' + (now.getMonth()+1)).slice(-2)

  articleDir = path.join('articles', util.format("%s/%s/", year, month))
  articleFile = path.join(articleDir, urlSlug + '.md')

  potterArticleFile = path.join(process.cwd(), 'potter', 'data', 'articles.json')
  potterTagFile = path.join(process.cwd(), 'potter', 'data', 'tags.json')

  potterArticleData = {}
  potterTagData = {}

  articleData = title: title, path: articleFile, createdAt: now.getTime(), tags: tagArray, published: false

  next 
    ERROR: (err) ->
      callback(err)
    checkPotterPath: ->
      inPotterPath(@next)
    mkdir: (inPotterPath) ->
      if not inPotterPath
        callback(new Error('Not in the root of a Potter CMS directory. Please navigate to the root of your Potter CMS directory.'))
      else
        fs.mkdir(articleDir, @next)
    loadPotterArticleData: ->
      fs.readFile(potterArticleFile, @next)
    touchArtcle: (err, articleJSON) ->
      potterArticleData = JSON.parse(articleJSON?.toString())
      potterArticleData = {} if not potterArticleData?
      potterArticleData.articles = {} if not potterArticleData.articles?
      potterArticleData?.articles[urlSlug + '-' + now.toISOString()] = articleData

      fs.writeFile(articleFile, '', @next)
    saveArticleData: ->
      #console.log('save article data')
      fs.writeFile(potterArticleFile, JSON.stringify(potterArticleData, null, 4), @next)
    loadTagArticle: ->
      fs.readFile(potterTagFile, @next)
    saveTagData: (err, tagJSON) ->
      #console.log('save tag data')
      potterTagData = JSON.parse(tagJSON?.toString())
      potterTagData = {} if not potterTagData?
      potterTagData.tags = {} if not potterTagData.tags?

      delete articleData.tags

      tagArray.forEach (tag) ->
        tagData = potterTagData.tags[tag] or= {articles: [], pages: []}
        tagData.articles.push(articleData)

      fs.writeFile(potterTagFile, JSON.stringify(potterTagData, null, 4), @next)
    done: ->
      callback(null, articleFile)

publish = (callback) ->
  potterConfFile = path.join(process.cwd(), 'potter', 'potter.json')
  potterConf = {}

  articleTemplateDir = path.join(process.cwd(), 'potter', 'article_template')
  potterArticleFile = path.join(process.cwd(), 'potter', 'data', 'articles.json')
  potterArticleData = {}

  buildDir = path.join(process.cwd(), 'build')
  articleBuildDir = path.join(buildDir, 'articles')

  outputFiles = []
  articlesToProcess = []

  layoutFile = path.join(process.cwd(), 'potter', 'article_template', 'layout.html')
  layoutTmpl = ''

  next
    ERROR: (err) ->
      throw err#callback(err)
    checkPotterPath: ->
      inPotterPath(@next)
    loadPotterConf: (inPotterPath) ->
      #console.log('loadPotterConf')
      if not inPotterPath
        callback(new Error('Not in the root of a Potter CMS directory. Please navigate to the root of your Potter CMS directory.'))
      else
        fs.readJSONFile(potterConfFile, @next)
    doesBuildDirExist: (err, obj) ->
      potterConf = obj
      fs.exists buildDir, @next
    makeBuildDir: (buildDirExists) ->
      #console.log('Make build dir')
      if buildDirExists
        @doesArticleBuildDirExist()
      else
        fs.mkdir buildDir, @next
    copyBootstrap: ->
      #console.log('copy bootstrap')
      fs.copy(P('vendor'), path.join(buildDir, 'vendor'), @next)
    doesArticleBuildDirExist: ->
      fs.exists articleBuildDir, @next
    makeArticleBuildDir: (articleBuildDirExists) ->
      if articleBuildDirExists
        @next()
      else
        fs.mkdir articleBuildDir, @next
    loadArticleData:  ->
      #console.log('loadArticleData')
      fs.readJSONFile(potterArticleFile, @next)
    gatherArticleData: (err, obj) ->
      potterArticleData = obj
      #console.log(potterArticleData)
      
      articles = []
      for key,articleObj of potterArticleData.articles
        #console.log key
        if not articleObj.published
          articles.push key: key, obj: articleObj
      
      articlesToProcess = articles
      @next()
    loadT1s: ->
      fs.readFile layoutFile, @next
    compileLess: (err, data) ->
      layoutTmpl = data.toString()
      @next()
      return

      variablesFile = P('vendor/bootstrap-2.0.4/themes/readable/variables.less')
      bootswatchFile = P('vendor/bootstrap-2.0.4/themes/readable/bootswatch.less')
      bootstrapFile = P('vendor/bootstrap-2.0.4/themes/readable/bootstrap.css')
      parser = new(less.Parser)

      fs.readFile variablesFile, (err, data) ->
        variablesLess = data.toString()
        fs.readFile bootswatchFile, (err, data) ->
          bootswatchLess = data.toString()
          #console.log bootswatchLess
          allLess = variablesLess + '\n' + bootswatchLess
          parser.parse allLess, (err, tree) ->
            if err? then console.log('LESS ERROR'); return;
            fs.writeFile bootstrapFile, tree.toCSS(compress: false), @next

    iterateArticles:  ->
      articles = articlesToProcess
      tf = TriggerFlow.create pending: articles.length, @next

      template = Handlebars.compile(layoutTmpl)
      urlTemplate = null

      if potterConf?.articles?.dateUrls?.enable
        urlTemplate = Handlebars.compile(potterConf.articles.dateUrls.format)

      for article in articles
        do (article) ->
          #console.log(article.obj.path)
          fs.readFile article.obj.path, (err, data) ->
            if err? then throw err
            slug = path.basename(article.obj.path, '.md')

            data = data.toString();
            md = marked(data);

            htmlFile = ''
            if potterConf?.articles?.dateUrls?.enable
              part = urlTemplate(dt.eval(new Date(article.obj.createdAt), 'date-'))
              htmlFile = path.join(articleBuildDir, part, slug + '.html')
            else
              htmlFile = path.join(articleBuildDir, slug + '.html')
            
            #console.log(htmlFile)
            #configs.package['bootstrap-path'] = '../vendor/bootstrap-2.0.4/css/bootstrap.min.css'
            configs.package['bootstrap-path'] = '../vendor/bootstrap-2.0.4/themes/readable/bootstrap.min.css'
            configs.package['highlight-path'] = '../vendor/highlight.js/styles/github.css'
            fs.writeFile htmlFile, template(body: md, potter: configs.package, title: article.obj.title), (err) ->
              outputFiles.push(htmlFile)
              tf.update pending: -1 
    generateIndex: ->
      Handlebars.registerHelper 'list', (items, options) ->
        out = ''
        for key,val of items
          out += options.fn(val)
        out

      fs.readFile path.join(process.cwd(), 'potter', 'article_template', 'index.html'), (err, data) =>
        delete potterConf.articles
        indexHtml = Handlebars.compile(data.toString())(_.extend(_.extend(potterArticleData, potter: configs.package), potterConf))
        fs.writeFile path.join(articleBuildDir, 'index.html'), indexHtml, @next
    
    done: ->
      callback(null, outputFiles)



module.exports.newSite = newSite
module.exports.newArticle = newArticle
module.exports.publish = publish


inPotterPath = (callback) ->
  articleDir = path.join(process.cwd(), 'articles')
  potterDir = path.join(process.cwd(), 'potter')

  next 
    1: ->
      fs.exists(articleDir, @next)
    2: (articleDirExists) ->
      if not articleDirExists
        callback(false)
      else
        fs.exists(potterDir, @next)
    3: (potterDirExists) ->
      if not potterDirExists
        callback(false)
      else
        callback(true)

