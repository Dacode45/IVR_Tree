# Example Tree Challenge

A simple scaffolding for implementing an IVR tree. All Node.js scripts are and should be written in **coffeescript**. Read more about the grammar of coffee script [here](http://coffeescript.org/).

#### Libraries

`src/handler.coffee`: A handler base class for constructing the IVR tree.
`src/dialer.coffee`: A dialer for simulating the call process.

#### Example

An example handler can be found in `src/example.coffee`. It implements a simple breathing question that accepts `1` or `2` as valid input.

The corresponding test can be found in `tests/example.coffee`.

#### Tests

All tests are written under the `mocha` framework. See [here](https://mochajs.org/) for more details.

## Goal

Your goal is to implement an Epharmix intervention using the provided libraries as well as to write unit tests that test against the correctness.
