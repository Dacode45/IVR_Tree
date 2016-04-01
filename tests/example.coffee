chai = require 'chai'
chai.config.includeStack = true
should = chai.should()
Dialer = require '../src/dialer'

describe 'Example Handler', ->

  handler = null
  dialer = null

  beforeEach (done) ->
    handler = require('../src/example')()
    dialer = new Dialer handler
    done()
    return

  it 'should handle a valid sequence (breathing better)', (done) ->
    dialer.next null, null, (hangup, res) ->
      hangup.should.be.false
      res.segments.length.should.equal 1
      res.segments[0].action.should.equal 'gather'
      res.segments[0].opts.numDigits.should.equal 1
      res.segments[0].children.segments[0].action.should.equal 'say'
      res.segments[0].children.segments[0].value.should.equal 'How are you breathing today? Press 1 if better, press 2 if worse.'
      return
    dialer.next 1, null, (hangup, res) ->
      hangup.should.be.true
      res.segments.length.should.equal 1
      res.segments[0].action.should.equal 'say'
      res.segments[0].value.should.equal 'Good to hear! You have a good day.'
      return
    done()
    return

  it 'should handler a valid sequence (breathing worse)', (done) ->
    dialer.next null, null, (hangup, res) ->
      hangup.should.be.false
      res.segments.length.should.equal 1
      res.segments[0].action.should.equal 'gather'
      res.segments[0].opts.numDigits.should.equal 1
      res.segments[0].children.segments[0].action.should.equal 'say'
      res.segments[0].children.segments[0].value.should.equal 'How are you breathing today? Press 1 if better, press 2 if worse.'
      return
    dialer.next 2, null, (hangup, res) ->
      hangup.should.be.true
      res.segments.length.should.equal 1
      res.segments[0].action.should.equal 'say'
      res.segments[0].value.should.equal 'I am sorry to hear that. Avoid outdoors if possible.'
      return
    done()
    return
