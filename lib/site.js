var P = require('autoresolve')
  , rock = require('rock')
  , path = require('path')
  , fs = require('fs-extra')
  , next = require('nextflow')
  , S = require('string')
  , dt = require('date-tokens')
  , parent = require('parentpath')
  , bd = require('batchdir')
  , Handlebars = require('Handlebars')
  , _ = require('underscore')
  , batchfile = require('batchfile')
  , util = require('util')
  , packageObj = require('../package')
  , buffet = require('buffet')
  , mdwalker = require('markdown-walker')
  , MarkdownPage = require('markdown-page').MarkdownPage

var DEFAULT_ROCK = 'personal_blog'
module.exports.DEFAULT_ROCK = DEFAULT_ROCK;

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


Site.prototype.createArticle = function(title, tags, openEditor, callback) {
  if (typeof openEditor === 'function') {
    callback = openEditor;
    openEditor = false;
  }
  
  var _this = this
    , articleFile = path.join(this.sitePath, 'articles', getDateMonthPath(), S(title).slugify() + '.md');
  
  fs.exists(articleFile, function(itExists) {
    if (itExists) return callback(new Error(articleFile + ' already exists.'));

    fs.touch(articleFile, function(err) {
      if (err) return callback(err);

      var data = '<!--\npublish: \ntags: ' + tags + '\n-->\n\n';
      data += title + '\n' + S('=').times(title.length) + '\n'
      fs.writeFile(articleFile, data, function(err) {
        if (err) return callback(err);

        //_this.addArticleEntry(title, parseTags(tags))
        callback(null, articleFile);
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
        batchfile(files).transform(function(i, file, data, write) {
          var mdp = MarkdownPage.create(data.toString());
          mdp.parse(function(err) {
            if (err) nf.error(err)

            var html = _this.articleTemplates['_article.html'].template({body: mdp.html, potter: potterData})
              , fstat = stats[i]
              , urlData = _.extend({slug: mdp.slug()}, dt["eval"](new Date(fstat.ctime), 'date-'))
              , relHtmlFile = urlFormat(urlData) + '.html'
              , htmlFile = path.join(buildArticleDir, relHtmlFile)

            _this.potterTemplates.main = html;
            html = _this.articleTemplates['layout.html'].template(templateVals);

            outputArticles[file] = {path: '/' + relHtmlFile, title: mdp.title, createdAt: fstat.ctime};
            write(htmlFile, html);
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
      outputArticles = _(outputArticles).sortBy(function(val) {
        return -val.createdAt;
      })
      var html = self.articleTemplates['_index.html'].template({
        articles: outputArticles,
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
    , port = process.env.PORT || 2222
    , server = require('http').createServer()
    , fileServer = buffet({root: _this.publicDir})
  
  server.on('request', function(req, res) {
    req.url = req.url;
    fileServer(req, res);
  });
  
  server.on('request', fileServer.notFound);
  server.listen(port, function() {
    console.log("Serving up " + _this.publicDir + " on port 2222...");
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

