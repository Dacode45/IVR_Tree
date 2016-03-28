###
Response

A pseudo response context that emulates a Twiml response, implementing the 
two keywords relevant for calls: say and gather
###
class Response

  # @property [Array<Object>] response segments
  segments: undefined

  constructor: ->
    @segments = []
    return

  ###
  Say something

  @param [String] message the message to say
  ###
  say: (message) ->
    @segments.push
      action: 'say'
      value: message
    return

  ###
  Gather digits

  @param [Object] opts options for gather
  @option opts [String] node the id of the node to send the digits to
  @option opts [String] finishOnKey the key to terminate the input, optional
  @option opts [Integer] numDigits number of digits to expect, optional
  @param [Function] fn function for nesting actions
  ###
  gather: (opts, fn) ->
    segment = 
      action: 'gather'
      opts: opts
      children: null
    if fn?
      children = new Response()
      fn.call children
      segment.children = children
    @segments.push segment
    return

  ###
  To JSON string
  ###
  toString: ->
    return JSON.stringify @segments,  null, 2

###
CallNode

A class representing a specific node in the IVR tree.
###
class CallNode

  # @property [Integer] Node ID
  id: undefined
  # @property [CallNode] Parent node
  parent: undefined
  # @property [Array<CallNode>] Child nodes
  children: undefined
  # @property [Array<CalNodeLink>] Links to child nodes
  links: undefined
  # @property [Function] Respond function
  respond: undefined

  constructor: (@id, @parent, @respond) ->
    @children = []
    @links = []
    return

  addLink: (child, trigger) ->
    if child not in @children
      @children.push child
    @links.push new CallNodeLink this, child, trigger
    return

  nextNode: (handler, digits, body) ->
    for link in @links
      if link.trigger handler, digits, body
        if link.to.respond?
          link.to.respond handler.response, handler
        return link.to
    # If no link is taken, use the default link
    if @links.length > 0
      @defaultLinkRespond handler.response, handler
    return

  defaultLinkRespond: (res, handler) ->
    res.say 'Sorry we did not get that.'
    @respond res, handler
    return

###
CallNodeLink

A class representing a possible transition link between two nodes.
###
class CallNodeLink

  # @property [CallNode] From node
  from: undefined
  # @property [CallNode] To node
  to: undefined
  # @property [Function] Trigger function
  trigger: undefined

  constructor: (@from, @to, @trigger) ->
    return

###
CallHandler

An abstraction layer on top of the low level call APIs. It allows for building 
IVR trees in the intuitive way.
###
class CallHandler

  # @property [Object] Data context
  data: undefined
  # @property [Object] response context
  ctx: undefined
  # @property [Response] pseudo response writer
  response: undefined

  # @property [Array<CallNode>] Call nodes
  nodes: undefined
  # @property [CallNode] Name confirmation node
  confNode: undefined

  constructor: () ->
    @data = {}
    @nodes = []
    return

  ###
  Add a new node

  @param [CallNode] parent Parent node
  @param [Function] respond Respond function
  ###
  addNode: (parent, respond) ->
    i = @nodes.length
    node = new CallNode i, parent, respond
    @nodes.push node
    return node

  ###
  Handle a call step
  
  @param [Object] ctx pseudo context for emulating a http req/res
  @param [Object] data the data context to operate in
  ###
  handle: (ctx, data) ->
    # Reset context and response
    @ctx = ctx
    @response = new Response()
    @data = data
    # Get node id
    nodeId = @ctx.nodeId
    # Invoke node's transition function
    if @nodes[nodeId]?
      # Specific node
      digits = @ctx.digits
      @nodes[nodeId].nextNode this, digits
    else if @nodes.length > 0
      # Otherwise, start with root
      @nodes[0].respond @response, this
      digits = @ctx.digits
      @nodes[0].nextNode this, digits
    # Output response
    @ctx.response = @response
    return


# Expose call handler
module.exports = CallHandler