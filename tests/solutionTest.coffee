chai = require 'chai'
chai.config.includeStack = true
should = chai.should()
Dialer = require '../src/dialer'
Solution = require '../src/solution'
fs = require 'fs'
path = require 'path'

FindSegment = (action, segments) ->
  return segments.find (segment)-> segment.action is action

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
    hasScale: true

  handler = undefined
  dialer = undefined
  fChartData = undefined

  beforeEach (done) ->
    [handler, fChartData] = Solution.GenerateHandlerFromData(jsonFile, data)
    dialer = new Dialer handler
    done()

  it 'should hangup if wrong person', (done) ->
    dialer.next null, null, (hangup, res) ->
      say = FindSegment "say", res.segments
      say.value.should.equal "Welcome to ePharmix. Press any key to continue"
    dialer.next null, null, (hangup, res) ->
      say = FindSegment "say", res.segments
      say.value.should.equal 'Is your name David, Ayeke? Enter 1 for Yes. Enter 2 for No'
    dialer.next 2, null, (hangup, res) ->
      hangup.should.be.true
      say = FindSegment "say", res.segments
      say.value.should.equal 'Thank you for your responses. Please have a good day.'
    done()

    it 'should be able to walk through the tree assuming patient does not have a scale', (done) ->
      dialer.next null, null, (hangup, res) ->
        say = FindSegment "say", res.segments
        say.value.should.equal "Welcome to ePharmix. Press any key to continue"
      dialer.next null, null, (hangup, res) ->
        say = FindSegment "say", res.segments
        say.value.should.equal 'Is your name David, Ayeke? Enter 1 for Yes. Enter 2 for No'
      dialer.next 1, null, (hangup, res) ->
        hangup.should.be.false
        say = FindSegment "say", res.segments
        say.value.should.equal 'What is your systolic blood pressure? Enter using your keypad'
      done()

  it 'should be able to walk through the tree assuming patient has scale', (done) ->
    #console.log("Gather: ", fChartData.get("gather"))
    dialer.next null, null, (hangup, res) ->
      hangup.should.be.false
    dialer.next 1, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("gather").should.equal 1
    dialer.next 1, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("gather").should.equal 1
    dialer.next 30000, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("weight").should.equal 170
    dialer.next 200, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("weight").should.equal 200
    dialer.next 200, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("systolic").should.equal 100
    dialer.next 80, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("systolic").should.equal 80
    dialer.next 100, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("dystolic").should.equal 100
    dialer.next 110, null, (hangup, res) ->
      hangup.should.be.false
      #console.log(fChartData)
      fChartData.get("systolic").should.equal 110
    dialer.next 80, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("dystolic").should.equal 80
    dialer.next 1000, null, (hangup, res) ->
      hangup.should.be.false
      fChartData.get("heartRate").should.equal 80
    dialer.next 100, null, (hangup, res) ->
      hangup.should.be.true
      fChartData.get("heartRate").should.equal 100
    done()

describe 'Liquid Parser', ->

  jsonFile = JSON.parse(fs.readFileSync(path.resolve(__dirname, 'EpxHeartHealth.json'), 'utf8'));
  data =
    str1: "String 1"
    str2: "String 2"
    str3: "String 3"
    num1: 8
    num2: 4
    num3: 2
    bool1: true
    bool2: false

  handler = undefined
  dialer = undefined
  fChartData = undefined

  beforeEach (done) ->
    [handler, fChartData] = Solution.GenerateHandlerFromData(jsonFile, data)
    dialer = new Dialer handler
    done()

  it 'Should Parse Statements', (done) ->
    #Test Strings
    liquid = Solution.ParseLiquidString("{{str1}},{{str2}},{{str3}}", fChartData)
    liquid.should.equal "#{data.str1},#{data.str2},#{data.str3}"
    #Test Numbers
    liquid = Solution.ParseLiquidString("{{num1}},{{num2}},{{num3}}", fChartData)
    liquid.should.equal "#{data.num1},#{data.num2},#{data.num3}"
    #Test Boolean
    liquid = Solution.ParseLiquidString("{{bool1}},{{bool2}}", fChartData)
    liquid.should.equal "#{data.bool1},#{data.bool2}"

    #Test True False
    liquid = Solution.ParseLiquidExpression("{{bool1}} == {{bool2}}", fChartData)
    liquid.should.equal data.bool1 == data.bool2
    liquid = Solution.ParseLiquidExpression("{{bool1}} && {{bool2}}", fChartData)
    liquid.should.equal data.bool1 && data.bool2
    liquid = Solution.ParseLiquidExpression("{{bool1}} || {{bool2}}", fChartData)
    liquid.should.equal data.bool1 || data.bool2

    #Test Mathematic Expressions
    t1 = Solution.ParseLiquidExpression("{{num1}} - ({{num2}} + {{num3}})", fChartData)
    t1.should.equal (data.num1 - (data.num2 + data.num3))
    t2 = Solution.ParseLiquidExpression("({{num1}} * {{num2}}) / {{num3}}", fChartData)
    t2.should.equal (data.num1 * data.num2)/data.num3
    t3 = Solution.ParseLiquidExpression("({{num1}}*({{num2}} / {{num3}})) + ({{num1}} - ({{num2}} + ({{num3}} * {{num3}})))", fChartData)
    t3.should.equal (data.num1 * (data.num2 / data.num3)) + (data.num1 - (data.num2 + (data.num3 * data.num3)))
    done()
