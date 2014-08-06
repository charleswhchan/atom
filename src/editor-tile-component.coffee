{extend, toArray, isEqual} = require 'underscore-plus'
Decoration = require './decoration'

WrapperDiv = document.createElement('div')

module.exports =
class EditorTileComponent
  constructor: (@state) ->
    @lineNodesByLineId = {}
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}
    @renderedDecorationsByLineId = {}
    @cursorPixelRectsById = {}
    @cursorNodesById = {}

    @domNode = document.createElement('div')
    @domNode.style.position = 'absolute'
    @domNode.style['-webkit-transform'] = @getTransform()
    @domNode.style.height = @state.get('height') + 'px'
    @domNode.style.width = @state.get('width') + 'px'
    @buildLines()

  stateChangedForKeys: ->
    for key in arguments
      return true if @prevState?.get(key) isnt @state.get(key)
    false

  update: (newState) ->
    @prevState = @state
    @state = newState

    if @stateChangedForKeys('top', 'left')
      @domNode.style['-webkit-transform'] = @getTransform()

    if @stateChangedForKeys('width')
      @domNode.style.width = @state.get('width') + 'px'

    if @stateChangedForKeys('lines')
      @updateLines()

    # @clearScreenRowCaches() if newProps.lineHeightInPixels isnt @props.lineHeightInPixels
    # @updateLines()
    # @updateCursors()

  getTransform: ->
    "translate3d(#{@state.get('left')}px, #{@state.get('top')}px, 0px)"

  buildLines: ->
    startRow = @state.get('startRow')
    lines = @state.get('lines')

    linesHTML = ""
    lines.forEach (line, i) =>
      screenRow = startRow + i
      linesHTML += @buildLineHTML(line, screenRow)
    @domNode.innerHTML = linesHTML

    lines.forEach (line, i) =>
      screenRow = startRow + i
      lineNode = @domNode.children[i]
      @lineNodesByLineId[line.id] = lineNode
      @screenRowsByLineId[line.id] = screenRow
      @lineIdsByScreenRow[screenRow] = line.id

  updateLines: ->
    lines = @state.get('lines')
    @removeLineNodes(lines)
    @appendOrUpdateVisibleLineNodes(lines)

  removeLineNodes: (lines=[]) ->
    lineIds = new Set
    lines.forEach (line) -> lineIds.add(line.id.toString())

    for lineId, lineNode of @lineNodesByLineId when not lineIds.has(lineId)
      screenRow = @screenRowsByLineId[lineId]
      delete @lineNodesByLineId[lineId]
      delete @lineIdsByScreenRow[screenRow] if @lineIdsByScreenRow[screenRow] is lineId
      delete @screenRowsByLineId[lineId]
      delete @renderedDecorationsByLineId[lineId]
      @domNode.removeChild(lineNode)

  appendOrUpdateVisibleLineNodes: (visibleLines) ->
    startRow = @state.get('startRow')
    # {startRow, lineDecorations} = @props

    newLines = null
    newLinesHTML = null

    visibleLines.forEach (line, index) =>
      screenRow = startRow + index

      if @hasLineNode(line.id)
        @updateLineNode(line, screenRow)
      else
        newLines ?= []
        newLinesHTML ?= ""
        newLines.push(line)
        newLinesHTML += @buildLineHTML(line, screenRow)
        @screenRowsByLineId[line.id] = screenRow
        @lineIdsByScreenRow[screenRow] = line.id

      # @renderedDecorationsByLineId[line.id] = lineDecorations[screenRow]

    return unless newLines?

    WrapperDiv.innerHTML = newLinesHTML
    newLineNodes = toArray(WrapperDiv.children)
    for line, i in newLines
      lineNode = newLineNodes[i]
      @lineNodesByLineId[line.id] = lineNode
      @domNode.appendChild(lineNode)

  updateLineNode: (line, screenRow) ->
    startRow = @state.get('startRow')
    lineWidth = @state.get('width')
    lineHeightInPixels = @state.get('lineHeightInPixels')

    # {lineDecorations} = @props
    lineNode = @lineNodesByLineId[line.id]

    # decorations = lineDecorations[screenRow]
    # previousDecorations = @renderedDecorationsByLineId[line.id]

    # if previousDecorations?
    #   for id, decoration of previousDecorations
    #     if Decoration.isType(decoration, 'line') and not @hasDecoration(decorations, decoration)
    #       lineNode.classList.remove(decoration.class)
    #
    # if decorations?
    #   for id, decoration of decorations
    #     if Decoration.isType(decoration, 'line') and not @hasDecoration(previousDecorations, decoration)
    #       lineNode.classList.add(decoration.class)

    unless @screenRowsByLineId[line.id] is screenRow
      lineNode.style.top =  (screenRow - startRow) * lineHeightInPixels + 'px'
      lineNode.dataset.screenRow = screenRow
      @screenRowsByLineId[line.id] = screenRow
      @lineIdsByScreenRow[screenRow] = line.id

  clearScreenRowCaches: ->
    @screenRowsByLineId = {}
    @lineIdsByScreenRow = {}

  hasLineNode: (lineId) ->
    @lineNodesByLineId.hasOwnProperty(lineId)

  lineNodeForScreenRow: (screenRow) ->
    @lineNodesByLineId[@lineIdsByScreenRow[screenRow]]

  hasDecoration: (decorations, decoration) ->
    decorations? and decorations[decoration.id] is decoration

  buildLineHTML: (line, screenRow) ->
    startRow = @state.get('startRow')
    lineHeightInPixels = @state.get('lineHeightInPixels')
    width = @state.get('width')

    {text, fold, isSoftWrapped, indentLevel} = line

    classes = @getLineClasses(screenRow)
    top = (screenRow - startRow) * lineHeightInPixels
    style = "position: absolute; top: #{top}px; width: 100%;"

    lineHTML = """<div class="#{classes}" style="#{style}">"""

    if text is ""
      lineHTML += @buildEmptyLineInnerHTML(line)
    else
      lineHTML += @buildLineInnerHTML(line)

    lineHTML += '<span class="fold-marker"></span>' if fold?
    lineHTML += "</div>"
    lineHTML

  getLineClasses: (screenRow) ->
    return 'line'
    classes = ''
    if decorations = @props.lineDecorations[screenRow]
      for id, decoration of decorations
        if Decoration.isType(decoration, 'line')
          classes += decoration.class + ' '
    classes + 'line'

  buildEmptyLineInnerHTML: (line) ->
    invisibles = {}
    showIndentGuide = false
    # {showIndentGuide, invisibles} = @props
    {cr, eol} = invisibles
    {indentLevel, tabLength} = line

    if showIndentGuide and indentLevel > 0
      invisiblesToRender = []
      invisiblesToRender.push(cr) if cr? and line.lineEnding is '\r\n'
      invisiblesToRender.push(eol) if eol?

      lineHTML = ''
      for i in [0...indentLevel]
        lineHTML += "<span class='indent-guide'>"
        for j in [0...tabLength]
          if invisible = invisiblesToRender.shift()
            lineHTML += "<span class='invisible-character'>#{invisible}</span>"
          else
            lineHTML += ' '
        lineHTML += "</span>"

      while invisiblesToRender.length
        lineHTML += "<span class='invisible-character'>#{invisiblesToRender.shift()}</span>"

      lineHTML
    else
      # @buildEndOfLineHTML(line, @props.invisibles) or '&nbsp;'
      @buildEndOfLineHTML(line, {}) or '&nbsp;'

  buildLineInnerHTML: (line) ->
    # {invisibles, mini, showIndentGuide} = @props
    invisibles = {}
    mini = false
    showIndentGuide = false
    {tokens, text} = line
    innerHTML = ""

    scopeStack = []
    firstTrailingWhitespacePosition = text.search(/\s*$/)
    lineIsWhitespaceOnly = firstTrailingWhitespacePosition is 0
    for token in tokens
      innerHTML += @updateScopeStack(scopeStack, token.scopes)
      hasIndentGuide = not mini and showIndentGuide and (token.hasLeadingWhitespace or (token.hasTrailingWhitespace and lineIsWhitespaceOnly))
      innerHTML += token.getValueAsHtml({invisibles, hasIndentGuide})

    innerHTML += @popScope(scopeStack) while scopeStack.length > 0
    innerHTML += @buildEndOfLineHTML(line, invisibles)
    innerHTML

  buildEndOfLineHTML: (line, invisibles) ->
    # return '' if @props.mini or line.isSoftWrapped()
    return '' if line.isSoftWrapped()

    html = ''
    # Note the lack of '?' in the character checks. A user can set the chars
    # to an empty string which we will interpret as not-set
    if invisibles.cr and line.lineEnding is '\r\n'
      html += "<span class='invisible-character'>#{invisibles.cr}</span>"
    if invisibles.eol
      html += "<span class='invisible-character'>#{invisibles.eol}</span>"

    html

  updateScopeStack: (scopeStack, desiredScopes) ->
    html = ""

    # Find a common prefix
    for scope, i in desiredScopes
      break unless scopeStack[i] is desiredScopes[i]

    # Pop scopes until we're at the common prefx
    until scopeStack.length is i
      html += @popScope(scopeStack)

    # Push onto common prefix until scopeStack equals desiredScopes
    for j in [i...desiredScopes.length]
      html += @pushScope(scopeStack, desiredScopes[j])

    html

  popScope: (scopeStack) ->
    scopeStack.pop()
    "</span>"

  pushScope: (scopeStack, scope) ->
    scopeStack.push(scope)
    "<span class=\"#{scope.replace(/\.+/g, ' ')}\">"

  updateCursors: ->
    return
    {cursorPixelRects, startRow, lineHeightInPixels} = @props

    for id of @cursorPixelRectsById
      @removeCursorNode(id) unless cursorPixelRects?.hasOwnProperty(id)

    if cursorPixelRects?
      for id, newPixelRect of cursorPixelRects
        newPixelRect.top -= startRow * lineHeightInPixels

        if oldPixelRect = @cursorPixelRectsById[id]
          unless isEqual(oldPixelRect, newPixelRect)
            @updateCursorNode(id, newPixelRect)
        else
          @buildCursorNode(id, newPixelRect)

  updateCursorNode: (id, pixelRect) ->
    {top, left, height, width} = pixelRect
    @cursorNodesById[id].style.top = top + 'px'
    @cursorNodesById[id].style.left = left + 'px'
    @cursorNodesById[id].style.height = height + 'px'
    @cursorNodesById[id].style.width = width + 'px'
    @cursorPixelRectsById[id] = pixelRect

  buildCursorNode: (id, pixelRect) ->
    cursorNode = document.createElement('div')
    cursorNode.className = 'cursor'
    cursorNode.style.position = 'absolute'
    @cursorNodesById[id] = cursorNode
    @cursorPixelRectsById[id] = pixelRect
    @updateCursorNode(id, pixelRect)
    @domNode.appendChild(cursorNode)

  removeCursorNode: (id) ->
    @domNode.removeChild(@cursorNodesById[id])
    delete @cursorPixelRectsById[id]
    delete @cursorNodesById[id]