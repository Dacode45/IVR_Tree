###
An example handler
###

CallHandler = require './handler'

###
  Explicitly set the data types
###
ValidDataTypes =
  "Number": typeof 0,
  "String": typeof "",
  "Boolean": typeof "false"

###
  Handles fields sent in from the FlowChart to be used with liquid
  Nodes with a gather can change the fields with the field gatherAs
###
class FlowChartData

  ###
  constructor
  @param [Object] fields to use as well as their datatype
  ###
  constructor: (fields) ->
    @dataTypes = {}
    @dataTypes[key] = ValidDataTypes[dataType] for own key, dataType of fields
    @[key] = fields[key]


  ###
  reset fields with data
  @param [Object] fill in the original
  ###
  init: (data) ->
    @set key, value for own key, value of data

  ###
  sets a givien key of FlowChartData
  @param [String] key to for the FlowChartData
  @param [Object] value for the key

  ###
  set: (key, value) ->
    if key is not 'gather' and typeof value is not @dataTypes[key]
      throw new TypeError "Type Missmatch. Gave #{value} for type #{@dataTypes[key]}",
    @[key] = value

  ###
  Gets a given key of FlowChartData
  @param [String] key for value of Flow Chart Data
  ###
  get: (key) ->
    @[key]

###
Creates a node for the tree
@param [CallNode] parent. Optional node to be this node's parent
@param [Handler] handler. Required. handler to attach CallNode to
@param [Object] statement. Options for this node
@option statement [String] key. Identifier of this node from the FlowChart
@option statement [Boolean] gather. Wheter this node should collect digits
@option statement [String] description. Custom description for this node
@option statement [String] say. What should be said when graph reaches this point.
@param [FlowChartData] fChartData. Flow Chart data to use for parsing expressions
###
CreateCallNode = (parent, handler, statement, fChartData) ->
  node = handler.addNode parent, () ->
    return
  node.key = statement.key
  node.shouldGather = statement.gather
  node.shouldHangup = statement.hangup
  node.description = statement.description
  node.text = statement.say
  node.goto = statement.goto
  node.respond = (res, handler) ->
    res.gather
      node: @id
      numDigits: statement.numDigits
    , () ->
      if node.text
        res.say ParseLiquidString node.text, fChartData
    if node.shouldHangup
      res.hangup()
  return node

#Matches Strings Like 1_OR_2
THIS_OR_THAT_RE = /(\d+)_OR_(\d+)/
#Matches Strings Like 2_TO_10
X_TO_Y_RE = /(\d+)_TO_(\d+)/

###
Creates a Node to goto when input is invalid
@param [CallNode] parent. Parent to the validation node
@param [Handler] handler. Handler to attach node to.
@param [String] validation. Validation Type Currently Supports
                THIS_OR_THAT and X_TO_Y
###
CreateValidationNode = (parent, handler, validation) ->
  node = handler.addNode parent, () ->
    return
  node.key="#{validation}#{parent.key}"
  node.description = "#{validation} node for node #{parent.key}"

  switch true
    #Case THIS_OR_THAT
    when THIS_OR_THAT_RE.test(validation)
      match = THIS_OR_THAT_RE.exec(validation)
      valid = [match[1], match[2]]
      node.text = "Sorry, I couldn't understand your input. Remeber to enter #{valid[0]} or #{valid[1]}"
      node.respond = (res, handler) ->
        res.say @text
        #immediately go to the next node
        node.nextNode(handler)
      #Add circular links
      parent.addLink node, (handler, digits) ->
        return valid.indexOf(digits) is not -1
      node.addLink parent, (handler, digits) ->
        return true
      #console.log(parent)
    #Case X_TO_Y
    when X_TO_Y_RE.test(validation)
      match = X_TO_Y_RE.exec(validation)
      valid = [match[1], match[2]]
      node.text = "Sorry, I couldn't understand your input. Remeber to enter digits between #{valid[0]} and #{valid[1]}"
      node.respond = (res, handler) ->
        res.say @text
        node.nextNode(handler)

      parent.addLink node, (handler, digits) ->
        #console.log "Parent: ", parent.key
        #console.log("Testing Validation: ", digits not in [valid[0]...valid[1]], valid, digits)
        return digits not in [valid[0]...valid[1]]
      node.addLink parent, (handler, digits) ->
        return true
    else
      throw new EvalError("Unsupported Evaluation Type: #{validation}")
  return node

###
GenerateHandler, returnes a handler based off the FlowChart
bounded to the fChartData

@param [Object] FlowChart. Javascript Object fufilling the FlowChart requirements
@param [FlowChartData] fChartData. Initiated Flow Chart Data
###
GenerateHandler = (FlowChart, fChartData) ->
  handler = new CallHandler()
  nodes = {}

  root = handler.addNode null, (res, handler) ->
    return
  ##Find root
  for statement in FlowChart.statements
    if statement.start
      nodes[statement.key] = CreateCallNode(root, handler, statement, fChartData, nodes)
      nodes.root = nodes[statement.key]
      root.addLink nodes.root, (handler, digits) ->
        return true
      break

  if not nodes.root
    throw new SyntaxError("Need a statement with the key \"start\"")
  ##generate the initial list of nodes
  for statement in FlowChart.statements
    if not nodes[statement.key]?
      nodes[statement.key] = CreateCallNode(null, handler, statement, fChartData, nodes)
  ##go through all connections and add connections and statements if necessary
  for connection in FlowChart.connections
    from = nodes[connection.from]
    #Make several validation nodes and set from to the last node in the stack
    if connection.validation?
      for i in [0...connection.validation.length]
        CreateValidationNode(from, handler, connection.validation[i])

    ##Set the connection.
    if connection.to?
      to = nodes[connection.to]
      trigger = from.addLink to, (handler, digits) ->
        fChartData.set("gather", digits)
        if @gatherAs and typeof digits is fChartData.dataTypes[@gatherAs]
          fChartData.set(@gatherAs, digits)
        if @to.goto
          @to.nextNode
        return true
      trigger.gatherAs = connection.gatherAs
      trigger.connection = connection
      trigger.goto = connection.to.goto

    else if connection.if
      tests = []
      for test in connection.if
        to = nodes[test.to]
        tests.push test.test

        #Add Link
        trigger = from.addLink to, (handler, digits) ->
          #console.log @test
          fChartData.set("gather", digits)
          if @gatherAs and typeof digits is fChartData.dataTypes[@gatherAs]
            oldGatherAs = fChartData.get(@gatherAs)
            fChartData.set(@gatherAs, digits)
          result = ParseLiquidExpression(@test, fChartData)
          if not result
            fChartData.set(@gatherAs, oldGatherAs)
          else
            if @to.goto
              @to.nextNode(handler)
          return result

        trigger.goto = from.goto
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
          if @gatherAs and typeof digits is fChartData.dataTypes[@gatherAs]
            oldGatherAs = fChartData.get(@gatherAs)
            fChartData.set(@gatherAs, digits)
          if @to.goto
            @to.nextNode(handler)
          return true

        trigger.goto = from.goto
        trigger.gather = connection.gather
        trigger.gatherAs = connection.gatherAs

    else
      throw new SyntaxError("Connections must have a to or an if. #{connection}")

  return handler


###
GenerateHandlerFromData
@param [Object] FlowChart
@param [Object] data with fields from FlowChart
###
GenerateHandlerFromData = (FlowChart, data) ->

  template = new FlowChartData(FlowChart.fields)
  template.init(data)
  return [GenerateHandler(FlowChart, template), template]

#Matches all spaces
ALL_SPACES_RE = /\s+/g
#Helps removed extra spaces in {{}}
SPACES_FIELD_PREFIX_RE = /{/g
#Helps remove extra spaces in {{}}
SPACES_FIELD_SUFFIX_RE = /}/g

#Removes extra spaces. fields should be seperated by one space
stripString = (str) ->
  str.replace(/\s+/g, ' ').replace(ALL_SPACES_RE, ' ').replace(SPACES_FIELD_PREFIX_RE, '{')
      .replace(SPACES_FIELD_SUFFIX_RE, '}')
#Matches fields
LIQUID_FIELD_RE = /{{(\w+)}}/g
#Returns string with filled fields from fChartData
ParseLiquidString = (liquidString, fChartData) ->
  liquidString = stripString(liquidString)
  replacer = (match, p1) ->
    fChartData.get(p1)
  liquidString.replace(LIQUID_FIELD_RE, replacer)

#Returns the result of an expression from fChartData
ParseLiquidExpression = (liquidString, fChartData) ->
  liquidString = ParseLiquidString(liquidString, fChartData)
  [result, index] = WalkThroughLiquidExpression(liquidString, 0, false)
  return result

# will match strings like  5-wew 4.42 david john_52 00-99-s232-2392-1

ARGUMENT_RE = /(\w|\d|-|\.)+/
OPERATOR_RE = /(>=|<=|!=|==|&&|\|\||[\+>\-<\/\*|&\^])/
#Helper Function for ParseLiquidExpression
WalkThroughLiquidExpression = (liquidString, startingIndex, isInnerExpression) ->

  if startingIndex >= liquidString.length
    throw new Error("Should not call this function with the end of the string")
  leftHandArg = undefined
  rightHandArg = undefined
  operator = undefined

  strStartIndex = undefined
  strEndIndex = undefined
  pos = startingIndex
  while pos < liquidString.length
    if liquidString[pos] is ' '
      if not strStartIndex?
        pos++
        continue
    else if liquidString[pos] is '('
      [result, endingIndex] = WalkThroughLiquidExpression(liquidString, pos+1, true)
      #console.log "Result: ", result, liquidString.substring endingIndex
      #console.log "Current Argument: ", "#{leftHandArg}#{operator}#{rightHandArg}"
      if not leftHandArg?
        leftHandArg = result
      else if not rightHandArg?
        rightHandArg = result
      else
        throw new Error("Malformed Expression. All expressions must be wrapped in parentesis
          example (15 > 10) && (10 <= 12) not 5 > 10 && 10 <= 12. At: #{liquidString.substring(pos, liquidString.length)}")
      #console.log "Current Argument: ", "#{leftHandArg}#{operator}#{rightHandArg}"
      pos = endingIndex

    else if liquidString[pos] is ')'
      #console.log("Ending Inner Expression")
      if isInnerExpression
        #support blank expressions () and ({{field}}) expressions
        #console.log("Inner Expression: #{leftHandArg}#{operator}#{rightHandArg}")
        if leftHandArg and operator and not rightHandArg
          throw new Error("(#{leftHandArg}) (#{rightHandArg}) is not an expression. At: #{liquidString.substring(pos)}")
        leftHandArg = '' if not leftHandArg?
        operator = '' if not leftHandArg?
        rightHandArg = '' if not rightHandArg?
        return [eval("#{leftHandArg}#{operator}#{rightHandArg}"), pos]
      else
        #console.log pos
        throw new Error("Parsing Error. Unexpected Token: ). At #{liquidString.substring(pos)}")

    #At this point.Only an argument or opporator is left
    else
      #console.log "Found string:#{liquidString.substring pos}. #{leftHandArg}, #{operator}, #{rightHandArg}"
      if not leftHandArg?
        result = ARGUMENT_RE.exec liquidString.substring pos
        leftHandArg = result[0]
        pos = pos + result.index + result[0].length-1
      else if not operator?
        result = OPERATOR_RE.exec liquidString.substring pos
        operator = result[0]
        pos = pos + result.index + result[0].length-1
      else if not rightHandArg?
        result = ARGUMENT_RE.exec liquidString.substring pos
        #console.log "Assigining", result
        rightHandArg = result[0]
        pos = pos + result.index + result[0].length-1
      else
        throw new Error("Expression should only have Left and Right Hand Arge. At: #{liquidString.substring pos}")
    pos = pos + 1
    #console.log "rest:", liquidString.substring pos
  #Reached the end of the string
  if leftHandArg? and operator? and not rightHandArg?
    throw new Error("#{leftHandArg} #{operator} #{rightHandArg} is not an expression. At: #{liquidString.substring(pos, liquidString.length)}")
  leftHandArg = '' if not leftHandArg?
  operator = '' if not leftHandArg?
  rightHandArg = '' if not rightHandArg?
  return [eval("#{leftHandArg}#{operator}#{rightHandArg}"), pos]

module.exports =
  GenerateHandler: GenerateHandler
  GenerateHandlerFromData: GenerateHandlerFromData
  ParseLiquidString: ParseLiquidString
  ParseLiquidExpression: ParseLiquidExpression
