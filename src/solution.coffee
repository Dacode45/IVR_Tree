###
An example handler
###

CallHandler = require './handler'

###
  Set the data types
###
ValidDataTypes =
  "Number": typeof 0,
  "String": typeof "",
  "Boolean": typeof "false"

###
  Handles fields sent in from the FlowChart to be used with liquid
  @param [Object] data the fields paramater of a FlowChart
###
class FlowChartData
  constructor: (fields) ->
    @dataTypes = {}
    @dataTypes[key] = ValidDataTypes[dataType] for own key, dataType of fields
    @[key] = fields[key]

  init: (data) ->
    @set key, value for own key, value of data

  set: (key, value) ->
    if key is not 'gather' and typeof value is not @dataTypes[key]
      throw new Error "Type Missmatch. Gave #{value} for type #{@dataTypes[key]}",

    @[key] = value

  get: (key) ->
    @[key]

CreateCallNode = (parent, handler, statement, fChartData) ->
  node = handler.addNode parent, () ->
    return
  node.key = statement.key
  node.shouldGather = statement.gather
  node.shouldHangup = statement.hangup
  node.description = statement.description
  node.text = statement.say
  node.respond = (res, handler) ->
    res.gather
      node: @id
    , () ->
      if node.text
        @say ParseLiquidString node.text, fChartData
    if node.shouldHangup
      res.hangup()
  return node

THIS_OR_THAT_RE = /(\d+)_OR_(\d+)/
X_TO_Y_RE = /(\d+)_TO_(\d+)/

CreateValidationNode = (parent, handler, validation) ->
  node = handler.addNode parent, () ->
    return
  node.key="#{validation}#{parent.key}"
  node.description = "#{validation} node for node #{parent.key}"
  switch true
    when THIS_OR_THAT_RE.test(validation)
      match = THIS_OR_THAT_RE.exec(validation)
      valid = [match[1], match[2]]
      node.text = "Sorry, I couldn't understand your input. Remeber to enter #{valid[0]} or #{valid[1]}"
      node.respond = (res, handler) ->
        res.say @text
      parent.addLink node, (handler, digits) ->
        return valid.indexOf(digits) is not -1
      node.addLink parent, (handler, digits) ->
        return true
      #console.log(parent)

    when X_TO_Y_RE.test(validation)
      match = X_TO_Y_RE.exec(validation)
      valid = [match[1], match[2]]
      node.text = "Sorry, I couldn't understand your input. Remeber to enter digits between #{valid[0]} and #{valid[1]}"
      node.respond = (res, handler) ->
        res.say @text
      parent.addLink node, (handler, digits) ->
        console.log("Testing Validation: ", not digits in [valid[0]...valid[1]])
        return not digits in [valid[0]...valid[1]]
      node.addLink parent, (handler, digits) ->
        return true
    else
      throw new Error("Invalid Validation Type: #{Validation}")
  return node

GenerateHandler = (FlowChart, fChartData) ->
  handler = new CallHandler()
  nodes = {}

  ##Find root
  for statement in FlowChart.statements
    if statement.start
      nodes[statement.key] = CreateCallNode(null, handler, statement, fChartData)
      nodes.root = nodes[statement.key]
      break

  if not nodes.root
    throw new Error("Need a starting node")
  ##generate the initial list of nodes
  for statement in FlowChart.statements
    if not nodes[statement.key]?
      nodes[statement.key] = CreateCallNode(null, handler, statement, fChartData)

  ##go through all connections and add connections and statements if necessary
  for connection in FlowChart.connections
    from = nodes[connection.from]
    #Make several validation nodes and set from to the last node in the stack
    if connection.validation?
      validationNode = CreateValidationNode(from, handler, connection.validation[0])
      for i in [1...connection.validation.length]
        validationNode = CreateValidationNode(from, handler, connection.validation[1])
      #from = validationNode

    ## set an unconditional to
    if connection.to
      to = nodes[connection.to]
      from.addLink to, (handler, digits) ->
        fChartData.set("gather", digits)
        return true
    else if connection.if
      tests = []
      for test in connection.if
        to = nodes[test.to]
        tests.push test.test

        #Add Link
        trigger = from.addLink to, (handler, digits) ->
          fChartData.set("gather", digits)
          if @gatherAs
            oldGatherAs = fChartData.get(@gatherAs)
            fChartData.set(@gatherAs, digits)
          result = ParseLiquidExpression(@test, fChartData)
          if not result
            fChartData.set(@gatherAs, oldGatherAs)
          return result

        trigger.gather = connection.gather
        trigger.gatherAs = connection.gatherAs
        trigger.test = test.test


        #console.log(from)
        ##catch clause
      if connection.else
        to = nodes[connection.else]
        #Add Link
        trigger = from.addLink to, (handler, digits) ->
          fChartData.set("gather", digits)
          if @gatherAs
            oldGatherAs = fChartData.get(@gatherAs)
            fChartData.set(@gatherAs, digits)
          return true

        trigger.gather = connection.gather
        trigger.gatherAs = connection.gatherAs

    else
      throw new Error("Connections must have a to or an if. #{connection}")

  return handler



GenerateHandlerFromData = (FlowChart, data) ->

  template = new FlowChartData(FlowChart.fields)
  template.init(data)
  return [GenerateHandler(FlowChart, template), template]

ALL_SPACES_RE = /\s+/g
SPACES_FIELD_PREFIX_RE = /{/g
SPACES_FIELD_SUFFIX_RE = /}/g

stripString = (str) ->
  str.replace(/\s+/g, ' ').replace(ALL_SPACES_RE, ' ').replace(SPACES_FIELD_PREFIX_RE, '{')
      .replace(SPACES_FIELD_SUFFIX_RE, '}')

LIQUID_FIELD_RE = /{{(\w+)}}/g
ParseLiquidString = (liquidString, fChartData) ->
  liquidString = stripString(liquidString)
  replacer = (match, p1) ->
    fChartData.get(p1)
  liquidString.replace(LIQUID_FIELD_RE, replacer)

ParseLiquidExpression = (liquidString, fChartData) ->
  liquidString = ParseLiquidString(liquidString, fChartData)
  [result, index] = WalkThroughLiquidExpression(liquidString, 0, false)
  if eval(liquidString) != result
    console.log(eval(liquidString), result)
    throw new Error("Error In WalkThroughLiquidExpression")
  return result

# will match strings like  5-wew 4.42 david john_52 00-99-s232-2392-1

ARGUMENT_RE = /(\w|\d|-|\.)+/
OPERATOR_RE = /(>=|<=|!=|==|&&|\|\||[\+>\-<\|&\^])/
WalkThroughLiquidExpression = (liquidString, startingIndex, isInnerExpression) ->

  if startingIndex >= liquidString.length
    throw new Error("Should not call this function with the end of the string")
  leftHandArg = undefined
  rightHandArg = undefined
  operator = undefined

  strStartIndex = undefined
  strEndIndex = undefined

  for pos in [startingIndex...liquidString.length]
    if liquidString[pos] is ' '
      if not strStartIndex?
        continue
      strEndIndex = pos
      if not leftHandArg
        leftHandArg = liquidString.substring(strStartIndex, strEndIndex)
      else if not operator
        operator = liquidString.substring(strStartIndex, strEndIndex)
      else if not rightHandArg
        rightHandArg = liquidString.substring(strStartIndex, strEndIndex)
      else
        throw new Error("Malformed Request: #{liquidString.substring(pos)}")
      strStartIndex = undefined
      strEndIndex = undefined
      continue
    else if liquidString[pos] is '('
      [result, endingIndex] = WalkThroughLiquidExpression(liquidString, pos+1, true)
      if not leftHandArg
        leftHandArg = result
      else if not rightHandArg
        rightHandArg = result
      else
        throw new Error("Malformed Expression. All expressions must be wrapped in parentesis
          example (15 > 10) && (10 <= 12) not 5 > 10 && 10 <= 12. At: #{liquidString.substring(pos, liquidString.length)}")
      pos = endingIndex
    else if liquidString[pos] is ')'
      if isInnerExpression
        #support blank expressions () and ({{field}}) expressions
        if leftHandArg and operator and not rightHandArg
          throw new Error("(#{leftHandArg}) (#{rightHandArg}) is not an expression. At: #{liquidString.substring(pos, liquidString.length)}")
        leftHandArg = '' if not leftHandArg
        operator = '' if not leftHandArg
        rightHandArg = '' if not rightHandArg
        return [eval("#{leftHandArg}#{operator}#{rightHandArg}"), pos]
      else
        throw new Error("Parsing Error. Unexpected Token: )")

    #At this point.Only an argument or opporator is left
    else
      strStartIndex = pos if not strStartIndex?
  #Reached the end of the string
  if strStartIndex?
    if not leftHandArg
      leftHandArg = liquidString.substring(strStartIndex)
    else if not rightHandArg
      rightHandArg = liquidString.substring(strStartIndex)
    else
      throw new Error("Malfromed Request: #{liquidString.substring(strStartIndex)}")
  if leftHandArg and operator and not rightHandArg
    throw new Error("(#{leftHandArg}) (#{rightHandArg}) is not an expression. At: #{liquidString.substring(pos, liquidString.length)}")
  leftHandArg = '' if not leftHandArg
  operator = '' if not leftHandArg
  rightHandArg = '' if not rightHandArg
  return [eval("#{leftHandArg}#{operator}#{rightHandArg}"), pos]

module.exports =
  GenerateHandler: GenerateHandler
  GenerateHandlerFromData: GenerateHandlerFromData
  ParseLiquidString: ParseLiquidString
  ParseLiquidExpression: ParseLiquidExpression
