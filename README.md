fcf
===

failure cause management filter

audience
========

so far ist just an actano rplanx internal tool.

motivation
==========

a tool that executes a command and filters the stdio output for failure pattern.
Exits with an exitcode <> 0 if a failure pattern is detected or if the command itself has an exitcode <> 0

After the command exits a summary failure report is print to stdout.

usage
=====

coffescript is required to run this tool!

usage help

    fcf -h for usage help

run a filter job:
the command will be executed with node spawn. for that reason shell commands are not interpreted.

    fcf -c command command_args

quiet option:
 suppress all stdio output and just write to output in case of a failure detection.
 failures are reported "live" in that case (only if report option is text, the default).

    fcf -qc command command_args

report option:
output failure report in json format instead of the default text format

    fcf -r json -c command command_args

hint:
fcf is defining the env var MOCHA_IGNORE_FAIL by default. that makes our mocha test run all,
even if a mocha test fails. to prevent this behaviour you have to undefine the env var, for example like this:

    MOCHA_IGNORE_FAIL= fcf -c lake test

failure cause knowledge base
============================

rules are hard coded in the project. (TODO: rules should be defined in the project, not globally)

rules defined in the coffee file lib/fcf-rules.coffee

rules aŕe structured in categories. every category has one ore more groups.
every group has a title and a list of regular expression pattern.
every pattern is matched against every line of the command output.
if a pattern matches a failure is detected.

sample format of the fcf-rules file

    module.exports =
        test:
            mocha_test:
                title: 'mocha test failed'
	            regexp: [
	                /^not ok/
	            ]
            pre_test
                title: 'sub system check failed'
	            regexp: [
	                /^webapp sub-system check fail/
	            ]

development
============================

how to release a new version

	git tag -a v0.0.6 -m 'version 0.0.6'
    git push origin v0.0.6