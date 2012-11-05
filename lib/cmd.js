var fnoc = require('fnoc')
  , util = require('util')
  , P = require('autoresolve')
  , fs = require('fs')
  , Site = require(P('lib/site')).Site
  , parent = require('parentpath')
  , USAGE = util.format("\nPotter [%s]: Install project templates.\n", 'configs.package.version');

USAGE += "Usage: potter [new|article|a|build|page|pg|publish|pub|serve] [options]";

var opt = require('optimist').usage(USAGE)
  , argv = opt.argv;

function main(potterDir) {
  if (process.argv.length < 3) 
    return displayHelp();
  
  switch (process.argv[2]) {
    case '--version':
      console.log('Potter %s', 'configs.package.version');
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
        handleArticleArgs(articleArgs, argv.tags);
    case 'page':
    case 'pg':
        console.log('Page functionality not yet implemented.');
        break;
    case 'publish':
    case 'pub':
        console.log('functionality not yet implemented.');
        break;
    case 'build':
        var site = Site.create(potterDir);
        site.initialize(function(err) {
          if (err) return console.error(err);
          site.buildAllArticles(function(err, outputFiles) {
            if (err) return console.error(err);
            console.log("Successfully built.");
          });
        });
    case 'serve':
      site = Site.create(potterDir);
      site.serve();
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

  handleArticleArgs = function(args, tags) {
    var site;
    switch (args[0]) {
      case 'new':
        site = Site.create(potterDir);
        return Article.create(site).createNew(args[1], tags, function(err, file) {
          if (err != null) {
            console.error(err);
            return;
          }
          return console.log("Successfully created " + file + ".");
        });
      default:
        return displayArticleHelp();
    }
  };

main(process.cwd());


