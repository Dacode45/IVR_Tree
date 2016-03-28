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
