# Koha Overdues Trigger System - Performance Optimisation Specification

## Overview
Redesign the daily overdues processing system to handle large-scale libraries efficiently whilst supporting digest notifications and closed-days calculations.

## Core Requirements

### 1. Trigger Logic
- Actions trigger **only** on the exact day when `days_overdue == trigger_delay`
- Never re-trigger the same action for the same item (natural behaviour due to exact matching)
- Script runs once daily with configurable trigger date parameter
- Support backdated runs for failure recovery

### 2. Context-Based Rules
- Rules defined by context: `library + patron_category + item_type`
- Fallback hierarchy (most specific to least specific):
  1. `library + patron_category + item_type`
  2. `library + patron_category`
  3. `library` only
  4. Global default (no context)
- Multiple rules per context possible, each with different delay values

### 3. Digest Notifications
- Patrons can opt for digest per notice type
- Group overdues by: `patron + notice_code + delay`
- Send single notice per group instead of individual notices
- Non-digest actions execute individually

### 4. Closed Days Handling
- System preference controls whether to exclude closed days from calculations
- Two processing paths required:
  - **Simple**: Use database `DATEDIFF` for performance
  - **Complex**: Application-level calculation excluding closed days per library calendar

## Algorithm Specification

### Main Processing Flow
```
1. Check system preference for closed days handling
2. Route to appropriate processing path
3. Pre-filter items to only those matching known delay values          DONE
4. Group items by days_overdue for batch processing                    DONE
5. Apply rule resolution with fallback hierarchy                       DONE
6. Queue actions with digest grouping                                  DONE
7. Execute grouped digest notices and individual actions               started
```

### Path 1: Simple Calculation (No Closed Days)
```sql
-- Single optimised query with pre-filtering
SELECT 
    i.itemnumber, i.biblionumber, i.itype as item_type,
    iss.borrowernumber, iss.date_due,
    b.categorycode as patron_category, b.branchcode as library_id,
    DATEDIFF(?, DATE(iss.date_due)) as days_overdue,
    bp.notice_preferences
FROM items i
JOIN issues iss ON i.itemnumber = iss.itemnumber
JOIN borrowers b ON iss.borrowernumber = b.borrowernumber  
LEFT JOIN borrower_preferences bp ON b.borrowernumber = bp.borrowernumber
WHERE DATE(iss.date_due) < DATE(?)
HAVING days_overdue IN (known_delay_values)
ORDER BY days_overdue, iss.borrowernumber
```

### Path 2: Closed Days Calculation
```
1. Fetch all overdue items without days calculation
2. For each item, calculate days_overdue using library calendar
3. Cache calendar objects per library for performance
4. Filter to items matching known delay values
5. Proceed with shared processing logic
```

### Rule Resolution System
```perl
# Caching resolver with fallback hierarchy
class OverdueRuleResolver {
    # Cache: "library|category|itemtype" => resolved_rules_array
    # Try contexts in order: full -> lib+cat -> lib -> global
    # Return first non-empty ruleset found
}
```

### Action Queueing and Execution
```
Digest Queue Structure:
- Key: "borrowernumber|notice_code|delay"  
- Value: array of {item, action, delay}

Individual Queue:
- Array of {item, action, delay}

Execute digest notices as single notice per digest key
Execute individual actions separately
```

## Performance Optimisations

### Database Level
- Single query for item retrieval with joins
- Pre-filter using `IN (known_delay_values)` in HAVING clause
- Index requirements:
  - `(library_id, patron_category, item_type)` for rule lookups
  - `(date_due)` for overdue selection
  - `(borrowernumber)` for patron data

### Application Level
- **Rule caching**: Build complete rule cache with fallback resolution at startup           YES (I think?)
- **Calendar caching**: One `Koha::Calendar` object per library, reused across items
- **Batch processing**: Group items by days_overdue to minimise rule lookups                NOT QUITE DOING I DON'T THINK - NEED CLARIFICATION ON INTENDED BEHAVIOUR HERE
- **Pre-filtering**: Only process items that could match existing rule delays               YES (I think?)

### Memory Optimisation
- Process items in batches if dataset is very large                                         DEFINE VERY LARGE?
- Clear processed items from memory during execution                                        NOT ENTIRELY SURE HOW ?
- Use array references for large datasets                                                   TRYING TO - WILL NEED REVIEW (my Perl hash understanding is getting there but...)

## Data Structures

### Item Structure                                                                          YES (IMPLEMENTED WITH ONE ADDITION)
```perl
{
    itemnumber => int,
    biblionumber => int, 
    item_type => string,
    borrowernumber => int,
    date_due => date,
    patron_category => string,
    library_id => string,
    days_overdue => int,
    notice_preferences => hashref
    replacementfee => decimal                                                             # ADDED (so we do not need to re-fetch items when enacting the 'charge' action)
}
```

### Rule Structure                                                                          YES (IMPLEMENTED)  
```perl
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

### Digest Group Structure                                                                  YESN'T (IMPLEMENTED, BUT WITH A TWIST - SEE QUESTIONS)
```perl
# Key format: "borrowernumber|notice_code|delay"
{
    "123|OVERDUE1|7" => [
        { item => item_hashref, action => action_hashref, delay => 7 },
        { item => item_hashref, action => action_hashref, delay => 7 }
    ]
}
```

## Implementation Guidelines

### Code Organisation
```
- Main script: process_circulation_triggers.pl
- Core module: Koha::Overdues::TriggerProcessor  
- Rule resolver: Koha::Overdues::RuleResolver  
- Calendar handler: Use existing Koha::Calendar
- Action executor: Koha::Overdues::ActionExecutor
```

### Error Handling
- Validate trigger date parameter
- Handle missing rule configurations gracefully
- Log processing statistics and errors
- Fail gracefully if calendar data unavailable

### Configuration
- System preference: `IgnoreClosedDaysInOverdueCalculation`
- Patron preference: digest settings per notice type
- Rule configuration: existing circulation rules structure

### Testing Considerations
- Unit tests for rule resolution fallback logic
- Performance tests with large datasets
- Test both closed-days paths
- Verify digest grouping correctness
- Test backdated run functionality

## Expected Performance Improvements
- **Database**: Single query instead of multiple lookups per item
- **Rule Resolution**: Cached resolution with hierarchy pre-computed
- **Calendar**: Cached calendar objects, only calculated when needed
- **Action Execution**: Batched digest notices reduce individual sends
- **Memory**: Process items in groups, minimal object retention

## Code Style Requirements
- Use Perl for all implementation
- Follow Koha coding standards
- Use American English spellings in code
- Comprehensive error handling and logging
- Performance-focused: minimize database queries and object instantiation

This specification provides the foundation for implementing a highly performant overdues system that scales to large library systems whilst maintaining all required functionality including digests and closed-days handling.