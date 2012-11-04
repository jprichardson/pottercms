var __hasProp = {}.hasOwnProperty
  , P = require('autoresolve')
  , rock = require('rock')
  , path = require('path')
  , fs = require('fs-extra')
  , next = require('nextflow')
  , S = require('string')
  , dt = require('date-tokens')
  , parent = require('parentpath')
  , bd = require('batchdir')
  , hl = require('highlight').Highlight
  , marked = require('marked')
  , Handlebars = require('Handlebars')
  , _ = require('underscore')
  , batchfile = require('batchfile')
  , util = require('util')
  , packageObj = require('../package')
  , buffet = require('buffet')({root: './build'})

var DEFAULT_ROCK = 'personal_blog'
module.exports.DEFAULT_ROCK = DEFAULT_ROCK;

Handlebars.registerHelper('list', function(items, options) {
  var key, out, val;
  out = '';
  for (key in items) {
    if (!__hasProp.call(items, key)) continue;
    val = items[key];
    out += options.fn(val);
  }
  return out;
});

marked.setOptions({
  gfm: true,
  pedantic: false,
  sanitize: true,
  highlight: function(code, lang) {
    return hl(code);
  }
});


    function Site(sitePath, rockTemplate) {
      this.sitePath = sitePath;
      this.rockTemplate = rockTemplate;
      this.potterDir = path.join(this.sitePath, 'potter');
      this.buildDir = path.join(this.sitePath, 'public');
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

        _this.addArticleEntry(title, parseTags(tags))
        callback(null, articleFile);
      })
    })
  })
}

    Site.prototype.addArticleEntry = function(title, tags) {
      var articleData, articleFile, month, now, slug, year;
      slug = S(title).slugify();
      now = new Date();
      year = dt["eval"](now)['year'];
      month = dt["eval"](now)['month'];
      articleFile = path.join('articles', year, month, slug + '.md');
      articleData = {
        title: title,
        path: articleFile,
        createdAt: now.getTime(),
        tags: tags,
        published: false
      };
      this.potterData['articles.json'].data.articles[slug + '-' + now.toISOString()] = articleData;
      return articleFile;
    };

    Site.prototype.generateSkeleton = function(callback) {
      return rock.create(this.sitePath, P('resources/rocks/' + this.rockTemplate), callback);
    };

    Site.prototype.initialize = function(callback) {
      var flow, self;
      self = this;
      return next(flow = {
        ERROR: function(err) {
          return callback(err);
        },
        loadPotterData: function() {
          var modifier;
          modifier = function(val) {
            val.data = JSON.parse(val.text);
            return delete val.text;
          };
          return loadFilesInDir(path.join(self.potterDir, 'data'), modifier, this.next);
        },
        loadArticleTemplateFiles: function(err, res) {
          var modifier;
          self.potterData = res;
          modifier = function(val) {
            val.template = Handlebars.compile(val.text);
            return delete val.text;
          };
          return loadFilesInDir(path.join(self.potterDir, 'article_template'), modifier, this.next);
        },
        loadPotterTemplateFiles: function(err, res) {
          var modifier, nf;
          nf = this;
          self.articleTemplates = res;
          modifier = function(val) {
            return val.text = Handlebars.compile(val.text)(self.potterData['potter.json']);
          };
          return loadFilesInDir(P('resources/partials'), modifier, function(err, res) {
            var file, val;
            if (err) {
              flow.error(err);
            } else {
              for (file in res) {
                if (!__hasProp.call(res, file)) continue;
                val = res[file];
                delete res[val];
                res[path.basename(file, '.html')] = val.text;
              }
            }
            self.potterTemplates = res;
            return nf.next();
          });
        },
        done: function() {
          self.initialized = true;
          self.potterData['potter.json'].data.homepage = packageObj.homepage;
          self.potterData['potter.json'].data.version = packageObj.version;
          return callback(null);
        }
      });
    };

    Site.prototype.buildAllArticles = function(callback) {
      var buildArticleDir, buildVendorDir, flow, outputArticles, potterData, self, templateVals, urlFormat;
      self = this;
      outputArticles = {};
      buildArticleDir = this.buildDir;
      buildVendorDir = path.join(this.buildDir, 'vendor');
      potterData = this.potterData['potter.json'].data;
      potterData.paths = potterData.paths || {};
      potterData.paths['bootstrap'] = 'http://netdna.bootstrapcdn.com/bootswatch/2.1.0/spacelab/bootstrap.min.css';
      potterData.paths['highlight'] = '/vendor/highlight.js/styles/github.css';
      urlFormat = Handlebars.compile(potterData.articles.urlFormat);
      templateVals = {
        self: null,
        template: this.potterTemplates,
        potter: potterData
      };
      return next(flow = {
        ERROR: function(err) {
          return callback(err);
        },
        buildArticleDir: function() {
          return bd(buildArticleDir).mkdir(this.next);
        },
        deleteVendorDir: function() {
          return bd(buildVendorDir).remove(this.next);
        },
        copyVendor: function() {
          return fs.copy(P('vendor'), buildVendorDir, this.next);
        },
        iterateArticles: function() {
          var articleFiles, articleKeys, articles, b, nf;
          nf = this;
          articles = self.potterData['articles.json'].data.articles;
          articleKeys = _(articles).keys();
          articleFiles = _(articles).pluck('path');
          articleFiles = articleFiles.map(function(file) {
            return path.join(self.sitePath, file);
          });
          b = batchfile(articleFiles).transform(function(i, file, data, write) {
            var articleData, html, htmlFile, md, relHtmlFile, slug, urlData;
            slug = path.basename(file, '.md');
            md = marked(data.toString());
            articleData = articles[articleKeys[i]];
            md = Handlebars.compile(md)({
              article: articleData
            });
            urlData = {
              slug: slug
            };
            urlData = _.extend(urlData, dt["eval"](new Date(articleData.createdAt), 'date-'));
            relHtmlFile = urlFormat(urlData) + '.html';
            htmlFile = path.join(buildArticleDir, relHtmlFile);
            html = self.articleTemplates['_article.html'].template({
              body: md,
              potter: potterData
            });
            self.potterTemplates.main = html;
            html = self.articleTemplates['layout.html'].template(templateVals);
            outputArticles[articleKeys[i]] = {
              path: '/' + relHtmlFile,
              title: articleData.title,
              createdAt: articleData.createdAt
            };
            return write(htmlFile, html);
          });
          b.error(function(err) {
            return nf.error(err);
          });
          return b.end(function() {
            return nf.next();
          });
        },
        generateIndex: function() {
          var html;
          outputArticles = _(outputArticles).sortBy(function(val) {
            return -val.createdAt;
          });
          html = self.articleTemplates['_index.html'].template({
            articles: outputArticles,
            potter: potterData
          });
          self.potterTemplates.main = html;
          html = self.articleTemplates['layout.html'].template(templateVals);
          return fs.writeFile(path.join(self.buildDir, potterData.articles.indexUrl), html, this.next);
        },
        done: function() {
          return callback(null);
        }
      });
    };

    Site.prototype.serve = function() {
      var port, server,
        _this = this;
      port = process.env.PORT || 2222;
      server = require('http').createServer();
      server.on('request', function(req, res) {
        req.url = req.url;
        return buffet(req, res);
      });
      server.on('request', buffet.notFound);
      return server.listen(port, function() {
        return console.log("Serving up " + (path.join(process.cwd(), _this.buildDir)) + " on port 2222...");
      });
    };

    Site.create = function(path, rock) {
      var r;
      r = rock || DEFAULT_ROCK;
      return new Site(path, r);
    };



  module.exports.Site = Site;

  loadFilesInDir = function(dir, valModifier, callback) {
    if (!callback) {
      callback = valModifier;
      valModifier = null;
    }
    return fs.readdir(dir, function(err, files) {
      var bf;
      if (err) {
        return callback(err, null);
      } else {
        files = files.map(function(f) {
          return path.join(dir, f);
        });
        bf = batchfile(files).read(function(i, file, data, next) {
          var fileKey, text, val;
          text = data.toString();
          fileKey = path.basename(file);
          val = {
            text: text,
            path: file,
            key: fileKey
          };
          if (valModifier) {
            valModifier(val);
          }
          return next(val);
        });
        bf.error(callback);
        return bf.end(function(results) {
          var obj, res, _i, _len;
          res = {};
          for (_i = 0, _len = results.length; _i < _len; _i++) {
            obj = results[_i];
            res[obj.key] = obj;
            delete obj.key;
          }
          return callback(null, res);
        });
      }
    });
  };



/***************************
* Private Methods
****************************/

function getDateMonthPath() {
  var date = new Date();
  return path.join(date.getFullYear().toString(), ('0' + (date.getMonth() + 1)).slice(-2));
}

function parseTags(tags) {
  if (!tags) return [];
  if (typeof tags === 'string') {
    var t = tags.split(',');
    if (t.length === 1)
      t = tags.split(' ');
    return t;
  } else if (tags instanceof Array) {
    return tags
  } else {
    return [];
  }
}
