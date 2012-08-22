configs = require('fnoc').configs()
util = require('util')
P = require('autoresolve')
potter = require(P('lib/potter'))
fs = require('fs')

USAGE = util.format("\nPotter [%s]: Install project templates.\n", configs.package.version);
USAGE += "Usage: potter [new|article|a|page|pg|publish|pub] [options]";

opt = require('optimist')
  .usage(USAGE)
#  .alias('a', 'article').describe('a', 'articles')
#  .alias('p', 'page').describe('p', 'pages')
argv = opt.argv;

main = ->
  if process.argv.length < 3
    displayHelp()
  else
    switch process.argv[2]
      when '--version'
        console.log('Potter %s', configs.package.version)
      when 'help'
        switch process.argv[3]
          when 'article', 'a'
            displayArticleHelp()
          when 'page', 'pg'
            displayPageHelp()
          when 'pub', 'publish'
            displayPublishHelp()
          when 'tag'
            displayTagHelp()
      when 'new'
        if process.argv[3]?
          if fs.existsSync process.argv[3]
            console.log("#{process.argv[3]} already exists.")
          else
            potter.newSite process.argv[3], (err) ->
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
        potter.publish (err, outputFiles) ->
          if err? then console.error(err); return
          console.log "Generated #{file}..." for file in outputFiles
          console.log "Successfully published."
      else displayHelp()


displayHelp = ->
  console.log(opt.help())

displayArticleHelp = ->
  console.log('potter [article|a] new title [--tags tags].')

displayPageHelp = ->
  console.log('Not yet implemented.')

displayPublishHelp = ->
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


main()

