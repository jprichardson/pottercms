var testutil = require('testutil')
  , path = require('path')
  , fs = require('fs-extra')
  , P = require('autoresolve')
  , Site = require(P('lib/site')).Site
  , bd = require('batchdir')
  , _ = require('underscore')
  , S = require('string')
  , next = require('nextflow');

var TEST_DIR = '';

describe('Site', function() {
  beforeEach(function(done) {
    TEST_DIR = testutil.createTestDir('potter');
    done();
  })
    
  describe('+ create()', function() {
    it('should create a Site object', function() {
      var site = Site.create('/tmp');
      T (site.sitePath === '/tmp')
    });
  })

  describe('- createArticle', function() {
    it('should create an article', function(done) {
      var site = Site.create(TEST_DIR, 'personal_blog');
      site.createArticle('Global Thermal Nuclear War', 'war, politics', function(err, file) {
        F (err)
        T (S(file).contains(path.join(TEST_DIR, 'articles')))
        var content = fs.readFileSync(file, 'utf8')
        T (S(content).contains('Global Thermal Nuclear War'))
        T (S(content).contains('war, politics'))
        done()
      })
    })
  })
    
    describe('- generateSkeleton()', function() {
      return it('should generate a new skeleton cms', function(done) {
        var site;
        site = Site.create(TEST_DIR, 'personal_blog');
        return site.generateSkeleton(function(err) {
          F(err != null);
          T(fs.existsSync(path.join(TEST_DIR, 'articles')));
          T(fs.existsSync(path.join(TEST_DIR, 'pages')));
          T(fs.existsSync(path.join(TEST_DIR, 'potter')));
          return done();
        });
      });
    });
    describe('- initialize()', function() {
      return it('should initialize the Site object with values', function(done) {
        var site;
        site = Site.create(TEST_DIR, 'personal_blog');
        return site.generateSkeleton(function(err) {
          F(err != null);
          return site.initialize(function(err) {
            F(err != null);
            T(site.initialized);
            return done();
          });
        });
      });
    });
    describe('- addArticleEntry()', function() {
      return it('should add an article entry into the article data file with a tag array', function(done) {
        var site;
        site = Site.create(TEST_DIR, 'personal_blog');
        return site.generateSkeleton(function(err) {
          return site.initialize(function(err) {
            var ad, articlePath, now, slug, tags, title;
            title = 'Global Thermal Nuclear War';
            slug = S(title).dasherize().toString().replace('-', '');
            tags = ['politics', 'war'];
            now = new Date();
            ad = site.potterData['articles.json'].data;
            T(_(ad.articles).size() === 0);
            articlePath = site.addArticleEntry(title, tags);
            T(S(articlePath).contains(now.getFullYear()));
            T(S(articlePath).contains((now.getMonth() + 1).toString()));
            T(S(articlePath).contains(slug));
            T(_(ad.articles).size() === 1);
            return done();
          });
        });
      });
    });
    
    describe('- buildAllArticles()', function() {
      it('should build all of the articles into a build dir with default options', function(done) {
        var buildDir = path.join(TEST_DIR, 'public')
          , articleDir = path.join(TEST_DIR, 'articles')
          , buildArticleDir = path.join(buildDir, 'articles')
          , t1 = 'The Fall of the Roman Empire'
          , t2 = 'Applications of Austrian Economics'
          , t3 = "Napoleon's Conquests"
          , s1 = 'the-fall-of-the-roman-empire'
          , s2 = 'applications-of-austrian-economics'
          , s3 = "napoleons-conquests"
          , o1 = path.join(buildArticleDir, s1 + '.html')
          , o2 = path.join(buildArticleDir, s2 + '.html')
          , o3 = path.join(buildArticleDir, s3 + '.html')
          , data = "{{article.title}}\n===============\n\nBlah blah blah"
          , site = Site.create(TEST_DIR, 'personal_blog');
        
        site.generateSkeleton(function(err) {
          if (err) return done(err)
          site.initialize(function(err) {
            if (err) return done(err)
            var flow;
            next(flow = {
              ERROR: function(err) {
                done(err);
              },
              createA1: function() {
                var nf = this;
                Article.create(site).createNew(t1, ['rome', 'history'], function(err, file) {
                  fs.writeFileSync(file, data);
                  nf.next();
                });
              },
              createA2: function() {
                var nf;
                nf = this;
                return Article.create(site).createNew(t2, ['economics', 'money'], function(err, file) {
                  fs.writeFileSync(file, data);
                  return nf.next();
                });
              },
              createA3: function() {
                var nf;
                nf = this;
                return Article.create(site).createNew(t3, ['history'], function(err, file) {
                  fs.writeFileSync(file, data);
                  return nf.next();
                });
              },
              publish: function() {
                return site.buildAllArticles(this.next);
              },
              checkPaths: function() {
                var index, indexFile;
                T(fs.existsSync(o1));
                T(fs.existsSync(o2));
                T(fs.existsSync(o3));
                T(fs.existsSync(path.join(buildDir, 'vendor')));
                T(S(fs.readFileSync(o1, 'utf8').toString()).contains('<h1>' + t1));
                T(S(fs.readFileSync(o2, 'utf8').toString()).contains('<h1>' + t2));
                indexFile = path.join(buildArticleDir, 'index.html');
                T(fs.existsSync(indexFile));
                index = fs.readFileSync(indexFile, 'utf8');
                T(S(index).contains(t1));
                T(S(index).contains(t2));
                return done();
              }
            });
          });
        });
      });
    });
  });

  Article = (function() {

    function Article(site) {
      this.site = site;
    }

    Article.prototype.createNew = function(title, tags, callback) {
      var articlePath, dir, flow, sp;
      if (typeof tags === 'string') {
        tags = tags.split(',').map(function(e) {
          return e.trim();
        });
      }
      articlePath = this.site.addArticleEntry(title, tags);
      dir = path.dirname(path.join(this.site.sitePath, articlePath));
      sp = this.site.sitePath;
      return next(flow = {
        ERROR: function(err) {
          return callback(err);
        },
        makeIt: function() {
          return bd(dir).mkdir(this.next);
        },
        done: function() {
          var file;
          file = path.join(sp, articlePath);
          return fs.writeFile(file, '', function(err) {
            return callback(err, file);
          });
        }
      });
    };

    Article.create = function(site) {
      return new Article(site);
    };

    return Article;

  })();


