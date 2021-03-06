#!/usr/bin/env coffee
fs = require 'fs'
path = require 'path'
{spawn} = require 'child_process'

carrier = require 'carrier'
_ = require 'underscore'
program = require 'commander'

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

rules = null
fcfRulesConfigFile = (baseDir, func) ->
    configFileName = 'fcf-rules.coffee'
    _fcfRulesConfigFile = (dir) ->
        fn = path.join(dir, configFileName)
        fs.exists fn, (exists) ->
            if exists
                return func fn
            parent = path.normalize(path.join(dir, '..'))
            if (parent isnt dir)
                return _fcfRulesConfigFile(parent)

            throw new Error("#{configFileName} not found in #{baseDir} and his parent directories");
    _fcfRulesConfigFile(baseDir)

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
    if i isnt -1
        return [argv[0...i], argv[(i+1)], argv[(i+2)..]]
    else
        return [argv]


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
    out = "------- fcf report match -------------------------------------------------------------\n"
    if match.preLines.length > 0
        out += colorIt(COLOR_GRAY, match.preLines.join('\n')) + "\n"
    out += colorIt(COLOR_FAIL, "#{match.category}:#{match.rule}: ")
    out += colorIt(COLOR_BRIGHT_FAIL, match.matchingLine) + "\n"
    if match.postLines.length > 0
        out += colorIt(COLOR_GRAY, match.postLines.join('\n')) + "\n"
    return out

failedSummaryTemplate = (matchSummary, exitCode) ->
    summary = ''
    _(matchSummary).each (nrOf, key) ->
        summary += "#{key} failed #{nrOf} time(s). "

    return """
        ------- fcf report summary start ------------------------------------------------------
        #{colorIt(COLOR_FAIL, "build failed with exitcode #{exitCode}")}
        #{colorIt(COLOR_FAIL, summary)}
        ------- fcf report summary end   ------------------------------------------------------
    """

successSummaryTemplate = ->
    return """
        ------- fcf report summary start ------------------------------------------------------
        #{colorIt(COLOR_OK, "build success")}
        ------- fcf report summary end   ------------------------------------------------------
    """

colorIt = (colorCode, str) ->
    if process.stdout.isTTY
        "#{colorCode}#{str}#{COLOR_OFF}"
    else
        str


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
        if not filterResult.success
            process.exit if filterResult.exitCode > 0 then filterResult.exitCode else 1


fcfRulesConfigFile process.cwd(), (fcfRulesConfigFileName)->
    rules = require(fcfRulesConfigFileName)
    main(process.argv)

