var fnoc = require('fnoc')
  , util = require('util')
  , P = require('autoresolve')
  , fs = require('fs')
  , Site = require(P('lib/site')).Site
  , parent = require('parentpath')
  , potterPkg = require('../package.json')
  , USAGE = util.format("\nPotter [%s]: Install project templates.\n", potterPkg.version)
  , open = require('open')

USAGE += "Usage: potter [new|article|a|build|page|pg|publish|pub|serve] [options]";

var opt = require('optimist').usage(USAGE)
  , argv = opt.argv;

function main(siteDir) {
  if (process.argv.length < 3) 
    return displayHelp();
  
  switch (process.argv[2]) {
    case '--version':
      console.log('Potter %s', potterPkg.version);
    case 'help':
      switch (process.argv[3]) {
        case 'article':
        case 'a':
          displayArticleHelp();
        case 'page':
        case 'pg':
          displayPageHelp();
        case 'pub':
        case 'publish':
          displayPublishHelp();
        case 'serve':
          displayServeHelp();
        case 'tag':
          displayTagHelp();
      }
      break;
    case 'new':
        if (process.argv[3] != null) {
          if (fs.existsSync(process.argv[3])) {
            console.log("" + process.argv[3] + " already exists.");
          } else {
            Site.create(process.argv[3]).generateSkeleton(function(err) {
              if (err) return console.log(err)
              console.log("Successfully created " + process.argv[3] + ".");
            });
          }
        } else {
          console.log('Error Invalid path.\n  potter new [path]');
        }
        break;
    case 'article':
    case 'a':
        var articleArgs = argv._.slice();
        articleArgs.splice(0, 1);
        handleArticleArgs(siteDir, articleArgs, argv.tags);
        break;
    case 'page':
    case 'pg':
        console.log('Page functionality not yet implemented.');
        break;
    case 'publish':
    case 'pub':
        console.log('functionality not yet implemented.');
        break;
    case 'build':
      var site = Site.create(siteDir);
      site.initialize(function(err) {
        if (err) return console.error(err);
        site.buildAllArticles(function(err, outputFiles) {
          if (err) return console.error(err);
          console.log("Successfully built.");
        });
      });
      break;
    case 'serve':
      site = Site.create(siteDir);
      site.initialize(function(err) {
        if (err) return console.error(err);
        site.serve();
      })
      break;
    default:
      displayHelp();
  }
}


  displayHelp = function() {
    return console.log(opt.help());
  };

  displayArticleHelp = function() {
    return console.log('potter [article|a] new title [--tags tags].');
  };

  displayPageHelp = function() {
    return console.log('Not yet implemented.');
  };

  displayPublishHelp = function() {
    return console.log('Not yet implemented.');
  };

  displayServeHelp = function() {
    return console.log('Not yet implemented.');
  };

  displayTagHelp = function() {
    return console.log('Not yet implemented.');
  };

function handleArticleArgs(siteDir, args, tags) {
  switch (args[0]) {
    case 'new':
      var site = Site.create(siteDir);
      site.createArticle(args[1], tags, function(err, file) {
        if (err) return console.error(err)
        console.log("Successfully created " + file + ".");
        open(file)
      })
      break;
    default:
      return displayArticleHelp();
  }
}

main(process.cwd());


