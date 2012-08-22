P = require('autoresolve')
path = require('path')
fs = require('fs-extra')
next = require('nextflow')

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
      dirExists: ->
        fs.exists dir, @next
      makeIt: (itDoesExist) ->
        if itDoesExist 
          @next
        else
          fs.mkdir dir, @next
      done: ->
        fs.writeFile path.join(sp, articlePath), '', callback


  @create: (site) ->
    new Article(site)


module.exports.Article = Article