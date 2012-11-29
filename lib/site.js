var P = require('autoresolve')
  , rock = require('rock')
  , path = require('path')
  , fs = require('fs-extra')
  , next = require('nextflow')
  , S = require('string')
  , dt = require('date-tokens')
  , parent = require('parentpath')
  , bd = require('batchdir')
  , Handlebars = require('handlebars')
  , _ = require('underscore')
  , batchfile = require('batchfile')
  , util = require('util')
  , packageObj = require('../package')
  , buffet = require('buffet')
  , mdwalker = require('markdown-walker')
  , MarkdownPage = require('markdown-page').MarkdownPage
  , batch = require('batchflow')

var DEFAULT_ROCK = 'personal_blog'
module.exports.DEFAULT_ROCK = DEFAULT_ROCK;

var BATCH_LIMIT = 64

Handlebars.registerHelper('list', function(items, options) {
  var out = '';
  _(items).each(function(val) {
    out += options.fn(val);
  })
  return out;
});

function Site(sitePath, rockTemplate) {
  this.sitePath = sitePath;
  this.rockTemplate = rockTemplate;
  this.potterDir = path.join(this.sitePath, 'potter');
  this.publicDir = path.join(this.sitePath, 'public');
  this.articleTemplates = {};
  this.potterData = {};
  this.potterTemplates = {};
  this.initialized = false;
}


Site.prototype.createArticle = function(title, tags, callback) {
  /*if (typeof openEditor === 'function') {
    callback = openEditor;
    openEditor = false;
  }*/
  
  var _this = this
    , mdp = MarkdownPage.create()
    , articleFile = path.join(this.sitePath, 'articles', getDateMonthPath())

  mdp.title = title
  articleFile = path.join(articleFile, mdp.slug() + '.md')
  
  fs.exists(articleFile, function(itExists) {
    if (itExists) return callback(new Error(articleFile + ' already exists.'));

    fs.touch(articleFile, function(err) {
      if (err) return callback(err);

      mdp.metadata.publish = ''
      
      if (tags)
        mdp.metadata.tags = tags instanceof Array ? tags : mdp.metadataConversions['tags'].deserialize(tags)
      
      mdp.writeFile(articleFile, function(err) {
        if (err)
          callback(err)
        else
          callback(null, articleFile)
      })
    })
  })
}

Site.prototype.generateSkeleton = function(callback) {
  rock.create(this.sitePath, P('resources/rocks/' + this.rockTemplate), callback);
}

Site.prototype.initialize = function(callback) {
  var flow = null
    , self = this

  next(flow = {
    ERROR: function(err) {
      callback(err);
    },
    loadPotterData: function() {
      function modifier(val) {
        val.data = JSON.parse(val.text);
        delete val.text;
      };
      loadFilesInDir(path.join(self.potterDir, 'data'), modifier, this.next);
    },
    loadArticleTemplateFiles: function(err, res) {
      self.potterData = res;
      function modifier(val) {
        val.template = Handlebars.compile(val.text);
        delete val.text;
      };
      loadFilesInDir(path.join(self.potterDir, 'article_template'), modifier, this.next);
    },
    loadPotterTemplateFiles: function(err, res) {
      var nf = this;
      self.articleTemplates = res;
      function modifier(val) {
        val.text = Handlebars.compile(val.text)(self.potterData['potter.json']);
      };
      loadFilesInDir(P('resources/partials'), modifier, function(err, res) {
        if (err) return nf.error(err)
        _(res).each(function(val, file) {
          delete res[file];
          res[path.basename(file, '.html')] = val.txt;
        })
        self.potterTemplates = res;
        nf.next();
      });
    },
    done: function() {
      self.initialized = true;
      self.potterData['potter.json'].data.homepage = packageObj.homepage;
      self.potterData['potter.json'].data.version = packageObj.version;
      callback(null);
    }
  });
};

Site.prototype.buildAllArticles = function(callback) {
  var self = this
    , _this = this
    , outputArticles = {}
    , buildArticleDir = this.publicDir
    , buildVendorDir = path.join(this.publicDir, 'vendor')
    , potterData = this.potterData['potter.json'].data
    , urlFormat = Handlebars.compile(potterData.articles.urlFormat)
    , templateVals = {self: null, template: this.potterTemplates, potter: potterData}
    
    potterData.paths = potterData.paths || {}
    potterData.paths['bootstrap'] = 'http://netdna.bootstrapcdn.com/bootswatch/2.1.0/spacelab/bootstrap.min.css';
    potterData.paths['highlight'] = '/vendor/highlight.js/styles/github.css';

  next({
    ERROR: function(err) {
      callback(err);
    },
    buildArticleDir: function() {
      bd(buildArticleDir).mkdir(this.next);
    },
    deleteVendorDir: function() {
      bd(buildVendorDir).remove(this.next);
    },
    copyVendor: function() {
      fs.copy(P('vendor'), buildVendorDir, this.next);
    },
    iterateArticles: function() {
      var nf = this
        , files = []
        , stats = []

      mdwalker(path.join(_this.sitePath, 'articles'))
      .on('markdown', function(file, stat) {
        files.push(file)
        stats.push(stat)  
      })
      .on('end', function() {
        batch(files).parallel(BATCH_LIMIT)
        .each(function(i, file, next) {
          MarkdownPage.readFile(file, function(err, mdp) {
            if (err) nf.error(err)

            if (mdp.metadata.publish) {
              var html = _this.articleTemplates['_article.html'].template({body: mdp.html, potter: potterData})
                , fstat = stats[i]
                , urlData = _.extend({slug: mdp.metadata.slug || slugify(mdp.title)}, dt["eval"](mdp.metadata.publish, 'date-'))
                , relHtmlFile = urlFormat(urlData) + '.html'
                , htmlFile = path.join(buildArticleDir, relHtmlFile)

              _this.potterTemplates.main = html;
              html = _this.articleTemplates['layout.html'].template(templateVals);

            
              outputArticles[file] = {path: '/' + relHtmlFile, title: mdp.title, createdAt: mdp.metadata.publish};
              fs.touch(htmlFile, function(err) { //shouldn't have to do this, `write()` should take care of it
                fs.writeFile(htmlFile, html, next)
              })
            } else {
              next()
            }
          })
        })
        .error(function(err) {
          nf.error(err)
        })
        .end(function() {
          nf.next()
        })
      })
    },
    generateIndex: function() {
      /*outputArticles = _(outputArticles).sortBy(function(val) {
        return -val.createdAt;
      })*/
      var newHtml = '';
      var groupedArticles = _(outputArticles).groupBy(function(a) {
        return a.createdAt.getFullYear();
      })

      var years = _(groupedArticles).keys()
      years = years.map(function(year) { return ~~year })
      years.sort()
      years.reverse();

      _(years).each(function(year) {
        var articles = groupedArticles[year];
        articles = _(articles).sortBy(function(a) {
          return -a.createdAt;
        })

        newHtml += '<h3>' + year + '</h3>\n';
        newHtml += '<ul>\n';
        articles.forEach(function(a) {
          newHtml += '  <li><a href="' + a.path + '"/>' + a.title + '</a></li>\n';
        })
        newHtml += '</ul>\n\n'; 
      })

      var html = self.articleTemplates['_index.html'].template({
        /*articles: outputArticles,*/
        articles: newHtml,
        potter: potterData
      })
      
      self.potterTemplates.main = html;
      html = self.articleTemplates['layout.html'].template(templateVals);
      fs.writeFile(path.join(self.publicDir, potterData.articles.indexUrl), html, this.next);
    },
    done: function() {
      callback(null);
    }
  });
}

Site.prototype.serve = function() {
  var _this = this
    , port = process.env.PORT || this.potterData['potter.json'].data.blog.port ||  2222
    , server = require('http').createServer()
    , fileServer = buffet({root: _this.publicDir})
  
  server.on('request', function(req, res) {
    req.url = req.url;
    fileServer(req, res);
  });
  
  server.on('request', fileServer.notFound);
  server.listen(port, function() {
    console.log("Serving up " + _this.publicDir + util.format(" on port %s...", port));
  });
};

Site.create = function(path, rock) {
  return new Site(path, rock || DEFAULT_ROCK);
};


module.exports.Site = Site;

function loadFilesInDir(dir, valModifier, callback) {
  if (!callback) {
    callback = valModifier;
    valModifier = null;
  }
  
  fs.readdir(dir, function(err, files) {
    if (err) return callback(err, null);
      
    files = files.map(function(f) { return path.join(dir, f) });
        
    batchfile(files).read(function(i, file, data, next) {
      var text = data.toString()
        , fileKey = path.basename(file)
        , val = {text: text, path: file, key: fileKey}
          
      if (valModifier) {
        valModifier(val);
      }
      next(val);
    })
    .error(callback)
    .end(function(results) {
      var res = {};
      for (var i = 0; i < results.length; ++i) {
        var obj = results[i];
        res[obj.key] = results[i];
        delete obj.key;
      }
      callback(null, res);
    })
  })
}



/***************************
* Private Methods
****************************/

function getDateMonthPath() {
  var date = new Date();
  return path.join(date.getFullYear().toString(), ('0' + (date.getMonth() + 1)).slice(-2));
}

function slugify(str) {
  return S(str.toLowerCase()).slugify().s;
}



