S = require('string')
mde = require('markdown-extra')

class Content
  constructor: (@text) ->

    @_metadata = null
    _getMetaData = ->
      if not @_metadata
        @_metadata = {}
        yml = mde.metadata(@text)
        S(yml).lines().forEach (line) =>
          if S(line).contains(':')
            data = line.split(':')
            @_metadata[data[0].trim()] = data[1].trim()
        if @_metadata['tags']
          if S(@_metadata['tags']).contains(',')
            @_metadata['tags'] = @_metadata['tags'].split(',').map((tag) -> tag.trim())
          else
            @_metadata['tags'] = [@_metadata['tags']]

        if @_metadata['publish']
          try
            @_metadata['publish'] = Date.parse(@_metadata.publish)
          catch e
      return @_metadata
    Object.defineProperty @, 'metadata', enumerable: true, get: _getMetaData
  
    @_title = null
    _getTitle = ->
      if not @_title
        @_title = mde.heading(@text)
      return @_title
    Object.defineProperty @, 'title', enumerable: true, get: _getTitle

    @_content = null
    _getContent = ->
      if not @_content
        @_content = mde.content(@text)
      return @_content
    Object.defineProperty @, 'content', enumerable: true, get: _getContent


  
  @create: (content) ->
    return new Content(content || '')


module.exports.Content = Content

