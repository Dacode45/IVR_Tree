module.exports = (grunt) ->

  grunt.loadNpmTasks 'grunt-mocha-test'

  grunt.initConfig
    mochaTest:
      test:
        options:
          reporter: 'spec'
          require: [
            'coffee-script/register'
          ]
          bail: grunt.option('bail')?
        src: ['tests/**/*.coffee']

  grunt.registerTask 'test', ['mochaTest']

  return