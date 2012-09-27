#TODO: fix configs.package.version

fnoc = require('fnoc')
util = require('util')
P = require('autoresolve')
fs = require('fs')
{Site} = require(P('lib/site'))
parent = require('parentpath')

USAGE = util.format("\nPotter [%s]: Install project templates.\n", 'configs.package.version');
USAGE += "Usage: potter [new|article|a|build|page|pg|publish|pub|serve] [options]";

opt = require('optimist')
  .usage(USAGE)
#  .alias('a', 'article').describe('a', 'articles')
#  .alias('p', 'page').describe('p', 'pages')
argv = opt.argv;

main = (potterDir) ->
  if process.argv.length < 3
    displayHelp()
  else
    switch process.argv[2]
      when '--version'
        console.log('Potter %s', 'configs.package.version')
      when 'help'
        switch process.argv[3]
          when 'article', 'a'
            displayArticleHelp()
          when 'page', 'pg'
            displayPageHelp()
          when 'pub', 'publish'
            displayPublishHelp()
          when 'serve'
            displayServeHelp()
          when 'tag'
            displayTagHelp()
      when 'new'
        if process.argv[3]?
          if fs.existsSync process.argv[3]
            console.log("#{process.argv[3]} already exists.")
          else
            Site.create(process.argv[3]).generateSkeleton (err) -> #potter.newSite process.argv[3], (err) ->
              if err? then console.log err; return
              console.log "Successfully created #{process.argv[3]}."
        else
          console.log('Error Invalid path.\n  potter new [path]')
      when 'article', 'a'
        articleArgs = argv._.slice()
        articleArgs.splice(0, 1)
        handleArticleArgs(articleArgs, argv.tags)
      when 'page', 'pg'
        console.log 'Page functionality not yet implemented.'
      when 'publish', 'pub'
        console.log 'functionality not yet implemented.'
      when 'build'
        site = Site.create(potterDir)
        site.initialize (err) ->
          if err then console.error(err); return
          site.buildAllArticles (err, outputFiles) ->
            if err? then console.error(err); return
            #console.log "Generated #{file}..." for file in outputFiles
            console.log "Successfully built."
      when 'serve'
        site = Site.create(potterDir)
        site.serve()

      else displayHelp()


displayHelp = ->
  console.log(opt.help())

displayArticleHelp = ->
  console.log('potter [article|a] new title [--tags tags].')

displayPageHelp = ->
  console.log('Not yet implemented.')

displayPublishHelp = ->
  console.log('Not yet implemented.')

displayServeHelp = ->
  console.log('Not yet implemented.')

displayTagHelp = ->
  console.log('Not yet implemented.')



handleArticleArgs = (args, tags) ->
  switch args[0]
    when 'new' 
      potter.newArticle args[1], tags, (err, file) ->
        if err? then console.error(err); return
        console.log "Successfully created #{file}."
    else displayArticleHelp()


#parent.find('potter/data/potter.json').end (dir) ->
#console.log (dir)
main(process.cwd())


