#!/usr/bin/env coffee

{spawn} = require 'child_process'
carrier = require 'carrier'
_ = require 'underscore'
program = require 'commander'

rules = require './fcf-rules'

NR_OF_PRELINES = 5
NR_OF_POSTLINES = 5

preLines = []
matches = []
postLineCollector = []
beQuit = false
logLive = false
spawnDefaultOptions =
    env:
        MOCHA_IGNORE_FAIL: true

filterLine = (line) ->
    return if not line?
    cleanLine = line.replace(/\033\[[0-9;]*[a-zA-Z]{1}/g, '')
    logLine(cleanLine)
    feedPostLines(cleanLine)
    matchLineWithAllPatterns(cleanLine)
    feedPreLines(cleanLine)


spawnAndFilter = (command, args, cb) ->
    _(spawnDefaultOptions.env).extend(process.env)
    childProcsess = spawn command, args, spawnDefaultOptions
    childProcsess.on 'close', (exitCode) ->
        finishPostLines()
        success = matches.length is 0 and exitCode is 0
        cb({matches, exitCode, success})

    carrier.carry childProcsess.stdout, filterLine
    carrier.carry childProcsess.stderr, filterLine


parseCommandArgs = (option, argv) ->
    i = argv.indexOf(option)
    return [argv[0...i], argv[(i+1)], argv[(i+2)..]]

main = (argv) ->
    [args, command, comandArgs] = parseCommandArgs('-c', argv)

    program
        .option('-r, --report [type]', 'type of report json | text', 'text')
        .option('-q, --quiet', 'do not log output to stdout', false)
        .option('-c, --command <command [args...]>', 'command to execute')
        .parse(args)

    if not command?
        return program.outputHelp()

    if not  _(['json', 'text']).contains(program.report)
        console.error "unknown reporter! #{program.report}"
        return program.outputHelp()

    beQuit = program.quiet
    logLive = program.quiet and program.report is 'text'

    spawnAndFilter command, comandArgs, (filterResult) ->
        if program.report is 'text'
            console.error createReport(filterResult)
        else
            console.error JSON.stringify(filterResult)

main(process.argv)


logLine = (line) ->
    if not beQuit
        console.log line

logMatch = (match) ->
    if logLive
        console.log lineMatchTemplate(match)


matchLineWithAllPatterns = (line) ->
    _(rules).each (category, categoryKey) ->
        _(category).each (rule, ruleKey) ->
            _(rule.regexp).each (regexp) ->
                if line.match regexp
                    match = {
                        title: rule.title
                        category: categoryKey
                        rule: ruleKey
                        preLines: getPreLines(rule.nrOfPreLines)
                        matchingLine: line
                        postLines: []
                    }
                    addPostLineCollector(match, rule.nrOfPostLines)
                    matches.push(match)


feedPreLines = (line) ->
    preLines.push line
    preLines = preLines.slice(-NR_OF_PRELINES)
    return

getPreLines = (nrOfLines = NR_OF_PRELINES) ->
    if nrOfLines > 0
        return preLines.slice(-nrOfLines)
    else
        return []


addPostLineCollector = (match, nrOfLines = NR_OF_POSTLINES) ->
    if nrOfLines is 0
        return logMatch(match)
    feed = (line) ->
        match.postLines.push(line)
        if match.postLines.length >= nrOfLines
            logMatch(match)
            return true
        return false
    postLineCollector.push {match, feed}

feedPostLines = (line) ->
    postLineCollector.forEach (item, i) ->
        if item.feed(line)
            postLineCollector.splice(i,1)

finishPostLines = ->
    postLineCollector.forEach (item, i) ->
        logMatch(item.match)
    postLineCollector = []

###
    reporting stuff
###

createReport = (filterResult) ->
    summary = createSummary(filterResult)
    if filterResult.success
        return summary
    else
        matchReport = if logLive then '' else createMatchReport(filterResult.matches)
        return matchReport + summary

createMatchReport = (matches) ->
    report = ""
    _(matches).each (match) ->
        report += lineMatchTemplate(match)
    return report

createSummary = (filterResult) ->
    if filterResult.success
        return successSummaryTemplate()
    else
        matchSummary = {}
        _(filterResult.matches).each (match) ->
            key = "#{match.category}:#{match.rule}"
            if not matchSummary[key]?
                matchSummary[key] = 1
            else
                matchSummary[key]++
        return failedSummaryTemplate(matchSummary, filterResult.exitCode)


COLOR_GRAY = '\u001b[90m'
COLOR_FAIL = '\u001b[31m'
COLOR_OK = '\u001b[32m'
COLOR_BRIGHT_FAIL = '\u001b[91m'
COLOR_OFF =  '\u001b[0m'

lineMatchTemplate = (match) ->
    out = "-------------------------------------------------------------------------------\n"
    if match.preLines.length > 0
        out += "#{COLOR_GRAY}#{match.preLines.join('\n')}#{COLOR_OFF}\n"
    out += "#{COLOR_FAIL}#{match.category}:#{match.rule}: #{COLOR_OFF}#{COLOR_BRIGHT_FAIL}#{match.matchingLine}#{COLOR_OFF}\n"
    if match.postLines.length > 0
        out += "#{COLOR_GRAY}#{match.postLines.join('\n')}#{COLOR_OFF}\n"
    return out

failedSummaryTemplate = (matchSummary, exitCode) ->
    summary = ''
    _(matchSummary).each (nrOf, key) ->
        summary += "#{key} failed #{nrOf} time(s). "

    return """
        -------------------------------------------------------------------------------
        #{COLOR_FAIL}build failed with exitcode #{exitCode}#{COLOR_OFF}
        #{COLOR_FAIL}#{summary}#{COLOR_OFF}
        -------------------------------------------------------------------------------
    """

successSummaryTemplate = ->
    return """
        -------------------------------------------------------------------------------
        #{COLOR_OK}build success#{COLOR_OFF}
        -------------------------------------------------------------------------------
    """




