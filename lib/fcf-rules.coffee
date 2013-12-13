module.exports =
    test:
        mocha_test:
            title: 'mocha test failed'
            nrOfPreLines: 0
            nrOfPostLines: 5
            regexp: [
                /^mocha not ok.*/
            ]

        pre_test:
            title: 'sub system state failed'
            nrOfPreLines: 0
            nrOfPostLines: 0
            regexp: [
                /^webapp sub-system check fail/
                /^couchbase sub-system check fail/
                /^bucket sub-system check fail/
                /^users_view sub-system check fail/
            ]

    infrastructure:
        github:
            title: 'github not reachable'
            nrOfPreLines: 2
            nrOfPostLines: 0
            regexp: [
                /failed to fetch ([^\,]*), got (\d{3})/
                /npm http ((4|5)\d{2})/
                /Error: socket hang up/
                /fatal: The remote end hung up unexpectedly/
                /npm ERR!.*git fetch/
            ]

        profitbricks:
            title: 'profitbricks failed'
            nrOfPreLines: 2
            nrOfPostLines: 2
            regexp: [
                /Timeout, server .* not responding/
                /WSDL._parse/
                /ERROR: expect one datacenter with pattern/
            ]

