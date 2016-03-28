###
An example handler
###

CallHandler = require './handler'

module.exports = () ->

  handler = new CallHandler()

  ###
  Root node

  Do nothing
  ###
  root = handler.addNode null, (res, handler) ->
    return

  ###
  Question node
  ###
  qNode = handler.addNode root, (res, handler) ->
    res.gather
      node: @id
      numDigits: 1
    , () ->
      @say 'How are you breathing today? Press 1 if better, press 2 if worse.'
      return
    return

  ###
  Root -> Question

  Always
  ###
  root.addLink qNode, (handler, digits) ->
    return true

  ###
  Better node
  ###
  bNode = handler.addNode qNode, (res, handler) ->
    res.say 'Good to hear! You have a good day.'
    return

  ###
  Question -> Better
  ###
  qNode.addLink bNode, (handler, digits) ->
    return 1 is parseInt digits

  ###
  Worse node
  ###
  wNode = handler.addNode qNode, (res, handler) ->
    res.say 'I am sorry to hear that. Avoid outdoors if possible.'
    return

  ###
  Question -> Worse
  ###
  qNode.addLink wNode, (handler, digits) ->
    return 2 is parseInt digits

  return handler