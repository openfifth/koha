#!/usr/bin/perl

# TODO: test and amend functionality for
#        - mark returned
#        - restrict
#        - notice (+ mtt)
#        - charge_cost
#      (so far the focus has been on set_lost)
# TODO: set and test sys prefs, amend accordingly
# TODO: add test for Koha::Checkouts->filter_by_overdue()
# DONE: modernized GetOverduesBy() to use filter_by_overdue() with SQL::Abstract syntax
# TODO: address the following questions:
#           - do we need a 'nomail' option ?
#           - how much logging to we want to do throughout the script?
#           - should account for 'DefaultLongOverduePatronCategories';
#           - should update and then use LostItem()? (+update tests)
#           - should account for WhenLostChargeReplacementFee ?

# Copyright 2008 Liblime
# Copyright 2010 BibLibre
#
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it
# under the terms of the GNU General Public License as published by
# the Free Software Foundation; either version 3 of the License, or
# (at your option) any later version.
#
# Koha is distributed in the hope that it will be useful, but
# WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
# GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License
# along with Koha; if not, see <http://www.gnu.org/licenses>.

use Modern::Perl;

use Getopt::Long qw( GetOptions );
use Pod::Usage   qw( pod2usage );
use Text::CSV_XS;
use DateTime;
use DateTime::Duration;

use Koha::Script -cron;
use C4::Context;
use C4::Letters;
use C4::Overdues qw( parse_overdues_letter );
use C4::Log      qw( cronlogaction );
use Koha::Logger;
use Koha::Patron::Debarments qw( AddUniqueDebarment );
use Koha::DateUtils          qw( dt_from_string output_pref );
use Koha::Calendar;
use Koha::Libraries;
use Koha::Acquisition::Currencies;
use Koha::Patrons;
use C4::Circulation qw( LostItem MarkIssueReturned );
use Koha::Checkouts;

=head1 NAME

circulation_triggers.pl - enact circulation triggers to handle long overdue items and send notices where relevant

=head1 SYNOPSIS

=head1 DESCRIPTION

This script is designed to update item lost and/or returned statuses,
borrower restrictions, and charge item lost fees. Depending on system
preferences and circulation triggers, it may also alert patrons and
administrators of overdue items.

=head2 Configuration

=head2 Outgoing emails

=head2 Templates

=head1 USAGE EXAMPLES

# irrelevant?

=head1 SEE ALSO

# relevant?
The F<misc/cronjobs/advance_notices.pl> program allows you to send
messages to patrons in advance of their items becoming due, or to
alert them of items that have just become due.

This script is intended as a replacement for both
F<misc/cronjobs/overdue_notices.pl> and 
F<misc/cronjobs/longoverdue.pl>.

=cut

my $dbh = C4::Context->dbh();
my ( $date_input, $today );

my @overduebranches = C4::Overdues::GetBranchcodesWithOverdueRules();                   # Branches with overdue rules
my @categories      = Koha::Patron::Categories->search()->get_column('categorycode');
my @itemtypes       = Koha::ItemTypes->search()->get_column('itemtype');

my $branchcount        = scalar(@overduebranches);
my $overduebranch_word = scalar @overduebranches > 1 ? 'branches' : 'branch';

my $date_to_run = dt_from_string();
my $date        = "NOW()";

binmode( STDOUT, ':encoding(UTF-8)' );

my %already_queued;
my %seen = map { $_ => 1 } @overduebranches;

# # Work through branches
my @output_chunks;
foreach my $branchcode (@overduebranches) {
    my $calendar;
    if ( C4::Context->preference('OverdueNoticeCalendar') ) {
        $calendar = Koha::Calendar->new( branchcode => $branchcode );
        if ( $calendar->is_holiday($date_to_run) ) {
            next;
        }
    }

    my $library             = Koha::Libraries->find($branchcode);
    my $admin_email_address = $library->from_email_address;
    my $branch_email_address =
        C4::Context->preference('AddressForFailedOverdueNotices') || $library->inbound_email_address;

    for my $borrower_category (@categories) {
        my $overdue_checkouts = Koha::Checkouts->filter_by_overdue(
            {
                item_homebranch     => $branchcode,
                patron_categorycode => $borrower_category,
                include_lost        => 0,
                require_notice      => 1
            }
        );

        my @overdues = map { $_->unblessed_all_relateds } $overdue_checkouts->as_list;

        my $borrowernumber;
        my $borrower_overdues_notices_triggers = {};
        foreach my $overdue (@overdues) {

            # handle first iteration
            unless ( defined $borrower_overdues_notices_triggers->{borrowernumber} ) {
                $borrower_overdues_notices_triggers = {
                    borrowernumber => $overdue->{borrowernumber},
                    branchcode     => $branchcode
                };

                # handle switching to the next patron
            } elsif ( $borrower_overdues_notices_triggers->{borrowernumber} ne $overdue->{borrowernumber} ) {
                _enact_notice_triggers_by_borrower($borrower_overdues_notices_triggers);
                $borrower_overdues_notices_triggers = {
                    borrowernumber => $overdue->{borrowernumber},
                    branchcode     => $branchcode
                };
            }

            # collect notice triggers for the patron, enact status change triggers
            _collect_or_enact_applicable_triggers(
                $borrower_overdues_notices_triggers,
                {
                    'borrower_category' => $borrower_category,
                    'branchcode'        => $branchcode,
                    'itemtype'          => $overdue->{itype} // $overdue->{itemtype},
                    'overdue'           => $overdue,
                    'calendar'          => $calendar
                }
            );
        }

        # handle the final borrower for the current category
        unless ( $borrower_overdues_notices_triggers->{borrowernumber} ) {
            next;
        }
        _enact_notice_triggers_by_borrower($borrower_overdues_notices_triggers);
        $borrower_overdues_notices_triggers = {};
    }

    unless (@output_chunks) {
        next;
    }
    my $content = join( "\n", @output_chunks );

    unless ( C4::Context->preference('EmailOverduesNoEmail') ) {
        next;
    }

    my $attachment = {
        filename => 'attachment.txt',
        type     => 'text/plain',
        content  => $content,
    };

    my $letter = {
        title   => 'Overdue Notices',
        content => 'These messages were not sent directly to the patrons.',
    };

    C4::Letters::EnqueueLetter(
        {
            letter                 => $letter,
            borrowernumber         => undef,
            message_transport_type => 'email',
            attachments            => [$attachment],
            to_address             => $branch_email_address,
        }
    );
}

=head1 INTERNAL METHODS

These methods are internal to the operation of circulation_triggers.pl.

=cut

sub _collect_or_enact_applicable_triggers {
    my ($borrower_overdues_notices_triggers) = shift;
    my ($parameters)                         = shift;

    my $i = 0;

    # iterate through triggers
PERIOD: while (1) {
        $i++;
        my $ii = $i + 1;

        my $overdue_rules = Koha::CirculationRules->get_effective_rules(
            {
                rules => [
                    "overdue_$i" . '_delay',         "overdue_$i" . '_notice',   "overdue_$i" . '_mtt',
                    "overdue_$i" . '_restrict',      "overdue_$i" . '_set_lost', "overdue_$i" . '_charge_cost',
                    "overdue_$i" . '_mark_returned', "overdue_$ii" . '_delay'
                ],
                categorycode => $parameters->{'borrower_category'},
                branchcode   => $parameters->{'branchcode'},
                itemtype     => $parameters->{'itemtype'},
            }
        );

        # end of overdue array reached, stop iterating.
        unless ( defined $overdue_rules->{ "overdue_$i" . '_delay' } ) {
            last PERIOD;
        }

        # check period compatibility
        my $mindays =
            $overdue_rules->{ "overdue_$i" . '_delay' };    # the notice will be sent after mindays days (grace period)
        my $maxdays = (
            $overdue_rules->{ "overdue_$ii" . '_delay' } - 1    # TODO: figure out what to do if this is not set!
        );    # issues being more than maxdays late are managed somewhere else. (borrower probably suspended)

        my $days_between;
        if ( C4::Context->preference('OverdueNoticeCalendar') ) {
            $days_between = $parameters->{calendar}->days_between(
                dt_from_string( $parameters->{overdue}->{date_due} ),
                $date_to_run
            );
        } else {
            $days_between =
                $date_to_run->delta_days( dt_from_string( $parameters->{overdue}->{date_due} ) );
        }
        $days_between = $days_between->in_units('days');

        unless ( $days_between >= $mindays
            && $days_between <= $maxdays )
        {
            # should log "Overdue skipped for trigger $i\n"; ?
            next;
        }

        # immediately enact relevant long overdue triggers
        # TODO: consider replacing these with _enact_long_overdue_triggers once control flow figured out
        my $set_lost = _get_set_lost_rule( $overdue_rules->{ "overdue_$i" . '_set_lost' } );
        if ( defined $set_lost ) {
            _enact_set_lost_trigger( $set_lost, $parameters->{overdue}->{itemnumber} );
        }

        my $charge_cost = _get_charge_cost_rule( $overdue_rules->{ "overdue_$i" . '_charge_cost' } );
        if ($charge_cost) {
            _enact_charge_cost_trigger(
                $charge_cost, $overdue_rules->{ "overdue_$i" . '_mark_returned' },
                $parameters->{overdue}->{itemnumber}
            );
        }

        if ( $overdue_rules->{ "overdue_$i" . '_mark_returned' } ) {
            _enact_mark_returned_trigger(
                $parameters->{overdue}->{borrowernumber},
                $parameters->{overdue}->{itemnumber}
            );
        }

        if ( $overdue_rules->{ "overdue_$i" . '_restrict' } ) {
            _enact_restrict_trigger(
                {
                    borrowernumber => $parameters->{overdue}->{borrowernumber},
                    firstname      => $parameters->{overdue}->{firstname},
                    surname        => $parameters->{overdue}->{surname},
                }
            );
        }

        # notice triggers are to be enacted per letter, per transport type (and not per overdue).
        # -> add the notice triggers to the $borrower_overdues_notices_triggers hash so they may be processed later.
        if ( defined $overdue_rules->{ "overdue_$i" . '_notice' } ) {
            _add_notice_rule_to_borrower_overdues_notices_triggers(
                {
                    notice         => $overdue_rules->{ "overdue_$i" . '_notice' },
                    restrict       => $overdue_rules->{ "overdue_$i" . '_restrict' },
                    mtt            => $overdue_rules->{ "overdue_$i" . '_mtt' },
                    overdue        => $parameters->{overdue},
                    trigger_number => $i,
                },
                $borrower_overdues_notices_triggers
            );
        }

        # SHOULD LOG?
        # my $borr = sprintf(
        # "%s%s%s (%s)",
        # $parameters->{overdue}->{surname} || '',
        # $parameters->{overdue}->{firstname} && $parameters->{overdue}->{surname} ? ', ' : '',
        # $parameters->{overdue}->{firstname} || '',
        # $parameters->{overdue}->{borrowernumber}
        # );
        #"Overdue matched trigger %s with delay of %s days and overdue due date of %s\n",
        # $i, $overdue_rules->{ "overdue_$i" . '_delay' }, $parameters->{overdue}->{date_due};
        # "Using letter code '%s'\n",
        # $overdue_rules->{ "overdue_$i" . '_notice' };
    }
}

sub _get_set_lost_rule {
    my ($set_lost_rule) = @_;
    if ( defined $set_lost_rule ) {
        return $set_lost_rule;
    }
    my $longoverdue_value = C4::Context->preference('DefaultLongOverdueLostValue');
    my $longoverdue_days  = C4::Context->preference('DefaultLongOverdueDays');
    if (    defined($longoverdue_value)
        and defined($longoverdue_days)
        and $longoverdue_value ne ''
        and $longoverdue_days ne ''
        and $longoverdue_days >= 0 )
    {
        return $longoverdue_value;
    }
    return undef;
}

sub _get_charge_cost_rule {
    my ($charge_cost_rule) = @_;
    if ( defined $charge_cost_rule ) {
        return $charge_cost_rule;
    }
    return C4::Context->preference('DefaultLongOverdueChargeValue');
}

# sub _get_mark_returned_rule {
#     if ($mark_returned) {
#         return $mark_returned;
#     }
#     # TODO:check if sys pref or other to serve as default?
#     # TODO:if not, simplify
#     return undef;
# }

# sub _get_restrict_rule {
#     if ($restrict) {
#         return $restrict;
#     }
#     # TODO:check if sys pref or other to serve as default?
#     # TODO:if not, simplify
#     return undef;
# }

#TODO: figure out control flow
sub _enact_long_overdue_triggers {
    my ($parameters) = @_;

    if ( $parameters->{set_lost} ) {
        my $lost_item = Koha::Items->find( $parameters->{itemnumber} );
        unless ( defined $parameters->{lost_item} ) {
            return;
        }
        $lost_item->itemlost( $parameters->{set_lost} );
        $lost_item->store;
    }

    # the item may already have been marked as lost in an earlier trigger
    LostItem(
        $parameters->{itemnumber}, 'cronjob', $parameters->{mark_returned},
        $parameters->{charge_cost}
    );

    if ( $parameters->{charge_cost} == 0 && $parameters->{mark_returned} ) {
        my $patron = Koha::Patrons->find( $parameters->{borrowernumber} );
        MarkIssueReturned( $parameters->{borrowernumber}, $parameters->{itemnumber}, undef, $patron->privacy );
    }
}

sub _enact_set_lost_trigger {
    my ( $set_lost, $itemnumber ) = @_;
    my $lost_item = Koha::Items->find($itemnumber);
    unless ( defined $lost_item ) {
        return;
    }
    $lost_item->itemlost($set_lost);
    $lost_item->store;
}

sub _enact_charge_cost_trigger {
    my ( $charge_cost, $mark_returned, $itemnumber ) = @_;

    # Update and use LostItem, or write script-specific method?
    LostItem(
        $itemnumber, 'cronjob', $mark_returned,
        $charge_cost
    );
}

sub _enact_mark_returned_trigger {
    my ( $borrowernumber, $itemnumber ) = @_;
    my $patron = Koha::Patrons->find($borrowernumber);
    MarkIssueReturned( $borrowernumber, $itemnumber, undef, $patron->privacy );
}

sub _enact_restrict_trigger {
    my ($borrower) = @_;
    AddUniqueDebarment(
        {
            borrowernumber => $borrower->{borrowernumber},
            type           => 'OVERDUES',
            comment        => "OVERDUES_PROCESS " . output_pref( dt_from_string() ),
        }
    );

    # TODO: should log?
    # my $borr = sprintf(
    #     "%s%s%s (%s)",
    #     $borrower->{surname} || '',
    #     $borrower->{firstname} && $borrower->{surname} ? ', ' : '',
    #     $borrower->{firstname} || '',
    #     $borrower->{borrowernumber}
    # );
    # "debarring $borr\n";
}

# straight from overdue_notices.pl
sub _add_notice_rule_to_borrower_overdues_notices_triggers {
    my ( $parameters, $borrower_overdues_notices_triggers ) = @_;

    my @message_transport_types = split( /,/, $parameters->{mtt} );

    for my $mtt (@message_transport_types) {
        push @{ $borrower_overdues_notices_triggers->{triggers}->{ $parameters->{trigger_number} }
                ->{ $parameters->{notice} }->{$mtt} }, $parameters->{overdue};
    }
    if ( $parameters->{restrict} ) {
        $borrower_overdues_notices_triggers->{restrict} = 1;
    }
    $borrower_overdues_notices_triggers->{email}          = $parameters->{overdue}->{email};
    $borrower_overdues_notices_triggers->{emailpro}       = $parameters->{overdue}->{emailpro};
    $borrower_overdues_notices_triggers->{B_email}        = $parameters->{overdue}->{B_email};
    $borrower_overdues_notices_triggers->{smsalertnumber} = $parameters->{overdue}->{smsalertnumber};
    $borrower_overdues_notices_triggers->{phone}          = $parameters->{overdue}->{phone};
}

# straight from overdue_notices.pl (minus the extraction to a method)
sub _enact_notice_triggers_by_borrower {
    my ($borrower_overdues_notices_triggers) = @_;

    my $borrowernumber = $borrower_overdues_notices_triggers->{borrowernumber};
    my $branchcode     = $borrower_overdues_notices_triggers->{branchcode};
    my $patron         = Koha::Patrons->find($borrowernumber);
    my ( $library, $admin_email_address, $branch_email_address );
    $library = Koha::Libraries->find($branchcode);

    # should keep?
    # $branch_email_address = C4::Context->preference('AddressForFailedOverdueNotices')

    my @emails_to_use = ();
    my $notice_email  = $patron->notice_email_address;
    push @emails_to_use, $notice_email if ($notice_email);

    for my $trigger ( sort keys %{ $borrower_overdues_notices_triggers->{triggers} } ) {
        for my $notice ( keys %{ $borrower_overdues_notices_triggers->{triggers}->{$trigger} } ) {
            my $print_sent = 0;    # A print notice is not yet sent for this patron
            for my $mtt ( keys %{ $borrower_overdues_notices_triggers->{triggers}->{$trigger}->{$notice} } ) {

                next if $mtt eq 'itiva';
                my $effective_mtt = $mtt;
                if (   ( $mtt eq 'email' and not scalar @emails_to_use )
                    or ( $mtt eq 'sms' and not $borrower_overdues_notices_triggers->{smsalertnumber} ) )
                {
                    # email or sms is requested but not exist, do a print.
                    $effective_mtt = 'print';
                }

                my $j                            = 0;
                my $exceededPrintNoticesMaxLines = 0;

                # Get each overdue item for this trigger
                my $itemcount            = 0;
                my $titles               = "";
                my @items                = ();
                my $PrintNoticesMaxLines = C4::Context->preference('PrintNoticesMaxLines');
                for my $item_info (
                    @{ $borrower_overdues_notices_triggers->{triggers}->{$trigger}->{$notice}->{$effective_mtt} } )
                {
                    if (   ( scalar(@emails_to_use) == 0 )
                        && $PrintNoticesMaxLines
                        && $j >= $PrintNoticesMaxLines )
                    {
                        $exceededPrintNoticesMaxLines = 1;
                        last;
                    }
                    next if $patron->homelibrary and !grep { $seen{ $item_info->{branchcode} } } @overduebranches;
                    $j++;

                    # figure out where to get @item_content_fields from
                    my @item_content_fields;
                    $titles .= C4::Letters::get_item_content(
                        { item => $item_info, item_content_fields => \@item_content_fields, dateonly => 1 } );
                    $itemcount++;
                    push @items, $item_info;
                }

                splice @items, $PrintNoticesMaxLines
                    if $effective_mtt eq 'print'
                    && $PrintNoticesMaxLines
                    && scalar @items > $PrintNoticesMaxLines;

                #catch the case where we are sending a print to someone with an email

                my $letter_exists = Koha::Notice::Templates->find_effective_template(
                    {
                        module                 => 'circulation',
                        code                   => $notice,
                        message_transport_type => $effective_mtt,
                        branchcode             => $branchcode,
                        lang                   => $patron->lang
                    }
                );

                unless ($letter_exists) {

                    # should log qq|Message '$notice' for '$effective_mtt' content not found|; /
                    next;
                }

                my $letter = parse_overdues_letter(
                    {
                        letter_code    => $notice,
                        borrowernumber => $borrowernumber,
                        branchcode     => $branchcode,
                        items          => \@items,
                        substitute     => {    # this appears to be a hack to overcome incomplete features in this code.
                            bib             => $library->branchname,    # maybe 'bib' is a typo for 'lib<rary>'?
                            'items.content' => $titles,
                            'count'         => $itemcount,
                        },

                        # If there is no template defined for the requested letter
                        # Fallback on the original type
                        message_transport_type => $letter_exists ? $effective_mtt : $mtt,
                    }
                );

                unless ( $letter && $letter->{content} ) {

                    # should log qq|Message '$notice' content not found|; ?
                    next;
                }

                if ($exceededPrintNoticesMaxLines) {
                    $letter->{'content'} .=
                        "List too long for form; please check your account online for a complete list of your overdue items.";
                }

                # my @misses = grep { /./ } map { /^([^>]*)[>]+/; ( $1 || '' ); } split /\</,
                #     $letter->{'content'};
                # if (@misses) {
                #     # should log "The following terms were not matched and replaced: \n\t" . join "\n\t", ?
                #         @misses;
                # }

                if (   ( $mtt eq 'email' and not scalar @emails_to_use )
                    or ( $mtt eq 'sms' and not $borrower_overdues_notices_triggers->{smsalertnumber} ) )
                {
                    push @output_chunks,
                        prepare_letter_for_printing(
                        {
                            letter         => $letter,
                            borrowernumber => $borrowernumber,
                            firstname      => $borrower_overdues_notices_triggers->{'firstname'},
                            lastname       => $borrower_overdues_notices_triggers->{'surname'},
                            address1       => $borrower_overdues_notices_triggers->{'address'},
                            address2       => $borrower_overdues_notices_triggers->{'address2'},
                            city           => $borrower_overdues_notices_triggers->{'city'},
                            postcode       => $borrower_overdues_notices_triggers->{'zipcode'},
                            country        => $borrower_overdues_notices_triggers->{'country'},
                            email          => $notice_email,
                            itemcount      => $itemcount,
                            titles         => $titles,
                            outputformat   => '',
                        }
                        );
                }
                if ( $effective_mtt eq 'print' and $print_sent == 1 ) {
                    next;
                }

                # Just sent a print if not already done.
                C4::Letters::EnqueueLetter(
                    {
                        letter                 => $letter,
                        borrowernumber         => $borrowernumber,
                        message_transport_type => $effective_mtt,
                        from_address           => $admin_email_address,
                        to_address             => join( ',', @emails_to_use ),
                        reply_address          => $library->inbound_email_address,
                    }
                );

                # A print notice should be sent only once per overdue level.
                # Without this check, a print could be sent twice or more if the library checks sms and email and print and the patron has no email or sms number.
                $print_sent = 1 if $effective_mtt eq 'print';
            }
            $already_queued{"$borrowernumber$trigger"} = 1;
        }
    }
}

=head2 prepare_letter_for_printing

returns a string of text appropriate for printing in the event that an
overdue notice will not be sent to the patron's email
address.

required parameters:
  letter
  borrowernumber

=cut

# straight from overdue_notices.pl, but removed any use of command flags
sub prepare_letter_for_printing {
    my $params = shift;
    return unless ref $params eq 'HASH';

    foreach my $required_parameter (qw( letter borrowernumber )) {
        return unless defined $params->{$required_parameter};
    }

    chomp $params->{titles};
    return "$params->{'letter'}->{'content'}\n";
}

=head2 _get_html_start

Return the start of a HTML document, including html, head and the start body
tags. This should be usable both in the HTML file written to disc, and in the
attachment.html sent as email.

=cut

# straight from overdue_notices.pl
sub _get_html_start {
    return "<html>
<head>
<meta http-equiv=\"Content-Type\" content=\"text/html; charset=utf-8\" />
<style type='text/css'>
pre {page-break-after: always;}
pre {white-space: pre-wrap;}
pre {white-space: -moz-pre-wrap;}
pre {white-space: -o-pre-wrap;}
pre {word-wrap: break-work;}
</style>
</head>
<body>";

}

=head2 _get_html_end
Return the end of an HTML document, namely the closing body and html tags.
=cut

# straight from overdue_notices.pl - won't use?
sub _get_html_end {
    return "</body>
</html>";
}

# =head2 skip_due_to_holiday
# Determines whether to skip notices or overdue actions due to holidays.
# =cut

# sub skip_due_to_holiday {
#     my ($branchcode) = @_;
#     my $calendar;
#     if ( C4::Context->preference('OverdueNoticeCalendar') ) {
#         $calendar = Koha::Calendar->new( branchcode => $branchcode );
#         if ( $calendar->is_holiday($date_to_run) ) {
#             return 1;
#         }
#     }
#     return 0;
# }

cronlogaction( { action => 'End', info => "COMPLETED" } );
