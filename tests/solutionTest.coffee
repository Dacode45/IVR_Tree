chai = require 'chai'
chai.config.includeStack = true
should = chai.should()
Dialer = require '../src/dialer'
Solution = require '../src/solution'
fs = require 'fs'
path = require 'path'

describe 'EpxHearthHealth Handler Validator', ->

  jsonFile = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'EpxHeartHealth.json'), 'utf8'));
  data =
    firstName: "David"
    lastName: "Ayeke"
    weight: 170
    systolic: 100
    dystolic: 89
    hasScale: true
    heartRate: 80
    weightThreshold: 200,
    bloodPressureThreshold: 120
    heartRateThreshold: 120

  handler = undefined
  dialer = undefined
  fChartData = undefined

  beforeEach (done) ->
    [handler, fChartData] = Solution.GenerateHandlerFromData(jsonFile, data)
    dialer = new Dialer handler
    done()

  it 'should be able to walk through the tree', (done) ->
    #console.log("Gather: ", fChartData.get("gather"))
    dialer.next 1, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("gather").should.equal 1
    dialer.next 3000, null, (hangup, res) ->
      hangup.should.be.false
    dialer.next 1, null, (hangup, res) ->
      hangup.should.be.false
    done()
