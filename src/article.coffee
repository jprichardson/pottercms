P = require('autoresolve')
path = require('path')
fs = require('fs-extra')
next = require('nextflow')
bd = require('batchdir')

class Article
  constructor: (@site) ->

  createNew: (title, tags, callback) ->
    if typeof tags is 'string'
      tags = tags.split(',').map((e) -> e.trim())
    
    articlePath = @site.addArticleEntry(title, tags)
    dir = path.dirname(path.join(@site.sitePath, articlePath))
    sp = @site.sitePath

    next flow =
      ERROR: (err) ->
        callback(err)
      makeIt: ->
        bd(dir).mkdir(@next)
      done: ->
        file = path.join(sp, articlePath)
        fs.writeFile file, '', (err) ->
          callback(err, file)



  @create: (site) ->
    new Article(site)


module.exports.Article = Article