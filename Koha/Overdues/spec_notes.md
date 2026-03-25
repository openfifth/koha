# TEMPORARY FILE - for ease of access during dev
## QUESTIONS
### general
- JUST TO CONFIRM:do we only take the date into account when applying triggers, and completely disregard times?
    - alternatively, do we interprete this as 'if date_due is 2025-10-10 14:00:00', then only enact if the script runs after 14:00:00.
###  Koha::Overdues::ActionExecutor
- QUESTION - HYPOTHETICALLY, DOES THIS SEEM ACCURATE ? :
    - the old overdue_notice.pl script has
    `push @{ $borrower_overdues->{triggers}->{$i}->{ $overdue_rules->{ "overdue_$i" . '_notice' } }->{$mtt} }, $data;`
    - but this spec indicates that the digest key should be
    `"borrowernumber|notice_code|delay" `
    which is incorrect. It needs to be something like 
    `"borrowernumber|notice_code|mtt|delay" `
    because it makes no sense to group action items together by notice but not by mtt (we can't batch handle different transport types)
    correct?

- JUST TO CONFIRM (EDGE CASE HANDLING): Key format for Digest Queue Structure to be "borrowernumber|notice_code|delay" 
    - that would not allow all notices for one borrower on one day to be grouped
    -   say I have borrowed a book and a CD ten day days ago
    -   say these are both 5 days overdue
    -   say the general rule for my library and patron category is "send an overdue notice"
    -   say for CDs specifically, it's 'send item due reminder' instead, for whatever reason
    We now have two separate emails and/or sms and/or print sent to the patron that day
    -> Is that the desired behaviour?
    -> Do we want instead to have the option to combine notices into one and send as one?
### Path 1: Simple Calculation (No Closed Days)
- is it alright for the grouping of notices to depend on Koha::Checkouts::GetOverduesSummaries() fetching grouping overdues by borrowers as it fetches them? Should there be some form of failsafe in place? 
### Closed Days Calculation
- ALTERNATIVE PROPOSAL: what if we work backwards instead?
    - pre-calculate target due dates by counting backwards from today for each known delay value, excluding closed days from the count.
    - use the same logic as for the simple calculation, having updated the know delay values accordingly.
    If this work, I think we'd get dryer code and better performance. It almost feels too simple an answer - is it?
### caching
- JUST TO CONFIRM: the intent is NOT to use my $memory_cache = Koha::Cache::Memory::Lite (we're just working with caching on object instances) correct?
### Koha::Overdues::TriggerProcessor
- QUESTION: provided the standard and digest queues both get processed completely separately:
    - do we need to process the standard (action) queue first?
    - do we need to process the digest (notice) queue first?
    - would we want to process both in parallel? - run separate scripts maybe, or however this might be possible? <em>genuinely does not know if that would work/ or how, but wondering</em>
### Koha::Overdues::RuleResolver
JUST TO CONFIRM: Does the following sound right?
- Getting potentially relevant overdue rules only
    - went with filtering down to context we know are relevant only
    - also only fetching overdue_ rules, not all circulation_rules row
- Resolving them (as "actions per delay for contexts"), and caching that.
- Treating this like an intermediary caching layer
    - store an array of potentially relevant rule sets
    - includes a method that effective resolves rule sets - that is, ties a rule set to an item batch being processed
- I might not have completely understood the resolved rules sets structure. That, or I have spotted an issue with it.
    - if the key is  library|category|itemtype
    - and if the value is 
    ```
         {
             delay => int,           # Days overdue to trigger
             actions => [            # Array of actions
                 {
                     type => string,        # 'notice', 'restrict', etc.
                     notice_code => string, # For notice actions
                     # ... other action parameters
                 }
             ]
         }
    ```
    We are failing to handle triggers - that is, the fact that for one context (library|category|itemtype), we will have sets of rules per trigger number -> different delays
    - Could we instead EITHER do
        -  key is  library|category|itemtype
        -  value is an object
        -  key is  delay
        -  value is unchanged

    - ALTERNATIVE PROPOSAL (what I've gone with) :
    ```
        library|category|itemtype|delay => {
             actions => [            # Array of actions
                 {
                     type => string,        # 'notice', 'restrict', etc.
                     notice_code => string, # For notice actions
                     # ... other action parameters
                 }
             ]
         }
    ```
    - OR
    ```
         {
             delay => int,           # Days overdue to trigger
             actions => [            # Array of actions
                 {
                     type => string,        # 'notice', 'restrict', etc.
                     notice_code => string, # For notice actions
                     # ... other action parameters
                 }
             ]
         }
    ```
    Would this make sense?
### Error handling
QUESTIONS:
- Validate trigger date parameter
    - is that delay? Trigger nnumber?
- Handle missing rule configurations gracefully
- Log processing statistics and errors
    - which statistics?
        - items
            - processed?
            - skipped (for good reason)
            - 'missed' => error occured
            - actions
                - executed?
                - 'missed' => error occured
        - notices sent?
        - for both the above -> per context?
    - where do we log to? (this very much is just me not knowing)
- Fail gracefully if calendar data unavailable
    - Do we need a clear message to admin users (full permissions) to indicate this occured (probably goes back to me not knowing where we're logging to)