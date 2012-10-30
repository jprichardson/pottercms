walker = require('walker')
path = require('path')
fs = require('fs-extra')
{EventEmitter} = require('events')
mde = require('markdown-extra')

class ContentWalker extends EventEmitter
  constructor: (@site, dir) ->
    @dir = path.join(@site.path, dir)
  walk: (lastPublished) ->
    lastPublished = lastPublished || new Date(0)
    walker = walker(@articleDir)
    walker.on 'file', (file, stat) ->
      if stat.mtime > lastPublished
        fs.readFile file, 'utf8', (err, text) ->

          @emit('content', file)

    walker.on 'error', (err) ->
      @emit('error', err)

    walker.on 'end', ->
      @emit('end')

  @create: (site) ->
    return new ArticleWalker(site)


###
PRIVATE FUNCTIONS
###

