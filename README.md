# Example Tree Challenge

A simple scaffolding for implementing an IVR tree. All Node.js scripts are and should be written in **coffeescript**. Read more about the grammar of coffee script [here](http://coffeescript.org/).

#### Install

You will need a `node` environment - anything above `0.11` should work. After you clone the repo, run `npm install` to get the dependencies.

You also want to run `npm install -g grunt-cli` in order to install `Grunt` the task runner. You might need to use `sudo`.

#### Libraries

`src/handler.coffee`: A handler base class for constructing the IVR tree.
`src/dialer.coffee`: A dialer for simulating the call process.

Read the documentation in the files to understand the usage.

#### Example

An example handler can be found in `src/example.coffee`. It implements a simple breathing question that accepts `1` or `2` as valid input.

The corresponding test can be found in `tests/example.coffee`.

#### Tests

All tests are written under the `mocha` framework. See [here](https://mochajs.org/) for more details.

To run the tests, simply run `grunt test`. If you do not wish to run the `example` tests during your development, rename `tests/example.coffee` to `tests/example`.

## Goal

Your goal is to implement an Epharmix intervention using the provided libraries as well as to write unit tests that test against the correctness. Tests should cover every valid paths as described in the pseudo code.

The sample intervention is described in `EpxHeartHealth.html` - note that this is not a real piece of pseudo code we use. There will be settings described in the pseudo code that are not provided to you in the libraries, you should devise a representation for your own use. Document all changes you make.

Your handler file (or anything else you add) should go under `src/`. Your test file should go under `tests/`. You may use any extra libraries you want.

## Solution

I wrote a simple script for creating IVR trees that work with the provided handler. I was able to replicate the paths in the pseudo code, as well as cover edge cases the pseudo code did not explicitly ask for
My solution has the Following Properties.

### Could be built by someone who isn't a programmer.

I wanted to write code that could create an IVR tree from an object.
This object then come from a file crafted by an employee of the company, or maybe a tool written by someone else.

I make the example json file for the tree in [EpxHeartHealth.json](\tests\EpxHeartHealth.json), and then I wrote
code capable of parsing it.

The object is made of 3 Properties.

1. `fields`, Fields of data object to be injected into the tree
2. `statements`, Nodes of the tree.
3. `connections`, Branches of the tree.

### Dynamically collect and receive data.

Statements can have fields dynamically injected into the string, and
connections can have expressions evaluated from the fields injected in.
A handler is generated by calling the `GenerateHandlerFromData` method
This method returns a handler, and a FlowChartData object that is bound to the tree. Changing a property of the FlowChartData object using the `set` method will change what that field in the tree. Trees can also
change the FlowChartData if a connection has a `gatherAs` field.

### Could use the data.

  Say the IVR tree would like to say the person's name. It should be able to retrieve that name on the fly, rather than having the name
  be hard coded or gotten at startup.

  I wrote code that parses strings with a given data object.
  The string `"Welcome {{FirstName}}, {{LastName}}"`, will be populated
  by the field names of the passed object to become
  `"Welcome David, Ayeke"`

  It can also parse expressions for evaluating connections
  Say a node only takes a connection if the user enters a number greater than the weightThreshold. The expression
  `"{{gather}} > {{weightThreshold}}"` would fulfill this requirement.

##The Rest of the ReadMe covers the code.

#1. Handlers
Handlers are created from the `GenerateHandlerFromData` method
`GenerateHandlerFromData` requires a `FlowChart` and a `data`

##1. A FlowChart

The FlowChart is an object with three properties

1. `fields`. An Object with the name of the fields to use and their
  dataType.
  Ex.
  ```
  "fields":{
    "firstName":"String",
    "lastName":"String",
    "weight":"Number",
    "systolic":"Number",
    "dystolic":"Number",
    "heartRate":"Number",
    "hasScale":"Boolean",
    "weightThreshold":"Number",
    "bloodPressureThreshold":"Number",
    "heartRateThreshold":"Number"
  }
  ```
  These fields can be used in expressions by escaping with `{{}}`
  For example `"{{firstName}}"` becomes `"David"`

  Trying to set FlowChartData fields that don't exist dataType (gather can be any dataType), or setting fields with values of the wrong dataType will throw a TypeError

2. `statements`. An Array of nodes. A statement can have the following fields. True false fields are assumed false if not given.
```
{"key":"Greeting", //The global key for this node
 "description":"Say Greeting", //Optional Description for this node
 "say":"Welcome to ePharmix. Press any key to continue", //What should be said when this node is reached
"start":true, //Is this the starting node
"goto":false, //After this node's say is said. Should it go immediately to the next node?
"hangup":true //Should you hangup here
},
```
The statements array must have a node with the start key.

3. `connections`. An Array of connections between nodes. A connection
can have the following fields

```
{"from":"ConfirmName", //Global Key of the Starting node
"if":[ //An Array of test to go to other nodes
  {"test":"{{gather}} == {{weight}}", //Expression to evaluate.
   "to":"HangUpMessage" //Node to go to if test passes
   },
],
"validation":["1_OR_2", "0_TO_3"]}, /*Gather Validations to happen before test. Possible validations are X_TO_Y. Numbers between x and y
exclusive, and THIS_OR_THAT. Gather can be something or another.
/*
"else":"HangUp" //Node to go to if all test fail.
"to": //Unconditionally go to this node
"gatherAs": weight /*Store the gather field as the given weight.
This happens before test are evaluated. */
```

Connections with a to field will always go to the node given by `to`.
Connections must have a `to` or an `if` field. The else field is only
evaluated if an `if` field is given.

##2. Using the code.

To use the code call the `GenerateHandlerFromData` method with a
FlowChart and an object with the data to inject into the FlowChart.
Ex.
```
[handler, fChartData] = Solution.GenerateHandlerFromData(FlowChart, dataObject)
dialer = new Dialer handler

```
