###
Dialer simulation

Emulates a phone call, where each step is the callee pressing a digit
###
class Dialer

  # @property [CallHandler] the call handler instance
  handler: undefined

  # @property [Object] previous context
  ctx: undefined

  constructor: (@handler) ->

  ###
  Find the gather statement
  ###
  _findGather: (segments) ->
    gather = null
    for segment in segments
      if segment.action is 'gather'
        gather = segment
        break
    return gather
  _shouldHangeUp: (segments) ->
    if not segments
      return false
    for segment in segments
      if segment.action is 'hangup'
        return true
    return false

  ###
  Step through the call sequence

  @param [String] digits digits for the step
  @param [Object] data object to be passed to the handler
  @param [Function] fn a function to run after the handle step
  ###
  next: (digits, data, fn) ->
    nodeId = null
    if @ctx?
      # Find the gather
      gather = @_findGather @ctx.response.segments
      if not gather?
        throw new Error 'No more next step in this sequence.'
      nodeId = gather.opts.node
    # Construct new context
    ctx =
      nodeId: nodeId
      digits: digits
    # Emulate a call step
    @handler.handle ctx, data
    @ctx = ctx
    # Check the hangup state
    gather = @_findGather ctx.response.segments
    # Fire the callback

    fn? @_shouldHangeUp(ctx.response.segments) or not gather?, ctx.response
    return

module.exports = Dialer
