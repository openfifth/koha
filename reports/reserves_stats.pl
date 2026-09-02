#!/usr/bin/perl

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
# along with Koha; if not, see <https://www.gnu.org/licenses>.

use Modern::Perl;

use CGI qw ( -utf8 );

use C4::Auth qw( get_template_and_user );
use C4::Context;
use C4::Koha    qw( GetAuthorisedValues );
use C4::Output  qw( output_html_with_http_headers );
use C4::Reports qw( GetDelimiterChoices );
use C4::Members;
use Koha::AuthorisedValues;
use Koha::ItemTypes;
use Koha::Libraries;
use Koha::Patron::Categories;
use List::MoreUtils qw( any );

=head1 NAME

reports/reserve_stats.pl

=head1 DESCRIPTION

Plugin that shows reserve stats

=cut

my $input          = CGI->new;
my $fullreportname = "reports/reserves_stats.tt";
my $do_it          = $input->param('do_it');
my $line_input     = $input->param("Line");
my $column_input   = $input->param("Column");
my $calc           = $input->param("Cellvalue");
my $output         = $input->param("output");
my $basename       = $input->param("basename");
my $hash_params    = $input->Vars;

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => $fullreportname,
        query         => $input,
        type          => "intranet",
        flagsrequired => { reports => '*' },
    }
);

# Line and Column values reach calculate() and are interpolated
# directly into a SELECT clause; any value not on this exact list is
# rejected to prevent SQL injection. The 15 names below are the
# checked-in radio buttons the wizard's own template
# (reserves_stats.tt) submits.
my %allowed_line_col = map { $_ => 1 } qw(
    reservestatus
    reservedate
    notificationdate
    reminderdate
    waitingdate
    cancellationdate
    borrowers.categorycode
    borrowers.sort1
    borrowers.sort2
    items.itype
    items.ccode
    items.location
    items.holdingbranch
    items.homebranch
    reserves.branchcode
);

# Legitimate filter parameter names (after stripping the `filter_`
# prefix) that the wizard's UI submits. Each is validated as an
# EXACT string match rather than derived by regex-stripping suffixes
# from the Line/Column allowlist — the two namespaces are related
# but not identical (e.g. `categorycode` here vs.
# `borrowers.categorycode` in the Line/Column list, and the
# reservestatus checkbox family uses `_or_C/F/P/W` suffixes with
# uppercase letters that a simple `s/_[a-z_]+$//` rewrite would not
# handle). The downstream WHERE builder interpolates the stripped
# filter name into SQL, so every entry below is (a) matched by the
# builder's own suffix logic (`_begin`, `_end`, `_endex`, `_or`, or
# bare) and (b) a safe bare-column reference in the joined query.
my %allowed_filter = map { $_ => 1 } qw(
    reservestatus_or_C
    reservestatus_or_F
    reservestatus_or_P
    reservestatus_or_W
    reservedate_begin
    reservedate_end
    notificationdate_begin
    notificationdate_end
    reminderdate_begin
    reminderdate_end
    waitingdate_begin
    waitingdate_end
    cancellationdate_begin
    cancellationdate_end
    categorycode
    items.itype
    items.ccode
    items.location
    items.holdingbranch
    items.homebranch
    items.itemcallnumber_begin
    items.itemcallnumber_endex
    reserves.branchcode
    borrowers.sort1
    borrowers.sort2
);

my $line =
    ( defined $line_input && $allowed_line_col{$line_input} )
    ? $line_input
    : 'reserves.branchcode';
my $column =
    ( defined $column_input && $allowed_line_col{$column_input} )
    ? $column_input
    : 'reservestatus';

my $filter_hashref;
foreach my $filter ( grep { $_ =~ /^filter_/ } keys %$hash_params ) {
    my $filterstring = $filter;
    $filterstring =~ s/^filter_//;
    next unless $allowed_filter{$filterstring};

    $$filter_hashref{$filterstring} = $$hash_params{$filter}
        if ( defined $$hash_params{$filter} && $$hash_params{$filter} ne "" );
}
our $sep = C4::Context->csv_delimiter( scalar $input->param("sep") );
$template->param(
    do_it => $do_it,
);

my @patron_categories =
    Koha::Patron::Categories->search_with_library_limits( {}, { order_by => ['description'] } )->as_list;

my $locations = {
    map { ( $_->{authorised_value} => $_->{lib} ) } Koha::AuthorisedValues->get_descriptions_by_koha_field(
        { frameworkcode => '', kohafield => 'items.location' }, { order_by => ['description'] }
    )
};
my $ccodes = {
    map { ( $_->{authorised_value} => $_->{lib} ) } Koha::AuthorisedValues->get_descriptions_by_koha_field(
        { frameworkcode => '', kohafield => 'items.ccode' }, { order_by => ['description'] }
    )
};

my $Bsort1 = GetAuthorisedValues("Bsort1");
my $Bsort2 = GetAuthorisedValues("Bsort2");
my ( $hassort1, $hassort2 );
$hassort1 = 1 if $Bsort1;
$hassort2 = 1 if $Bsort2;

if ($do_it) {

    # Displaying results
    my $results = calculate( $line, $column, $calc, $filter_hashref );
    if ( $output eq "screen" ) {

        # Printing results to screen
        $template->param( mainloop => $results );
        output_html_with_http_headers $input, $cookie, $template->output;
    } else {

        # Printing to a csv file
        print $input->header(
            -type       => 'application/vnd.sun.xml.calc',
            -encoding   => 'utf-8',
            -attachment => "$basename.csv",
            -filename   => "$basename.csv"
        );
        my $cols  = @$results[0]->{loopcol};
        my $lines = @$results[0]->{looprow};

        # header top-right
        print @$results[0]->{line} . "/" . @$results[0]->{column} . $sep;

        # Other header
        foreach my $col (@$cols) {
            print $col->{coltitle} . $sep;
        }
        print "Total\n";

        # Table
        foreach my $line (@$lines) {
            my $x = $line->{loopcell};
            print $line->{rowtitle} . $sep;
            print map { $_->{value} . $sep } @$x;
            print $line->{totalrow}, "\n";
        }

        # footer
        print "TOTAL";
        $cols = @$results[0]->{loopfooter};
        print map { $sep . $_->{totalcol} } @$cols;
        print $sep. @$results[0]->{total};
    }
    exit;    # exit either way after $do_it
}

my $dbh = C4::Context->dbh;

my $itemtypes = Koha::ItemTypes->search_with_localization;

# location list
my @locations;
foreach ( sort keys %$locations ) {
    push @locations, { code => $_, description => "$_ - " . $locations->{$_} };
}

my @ccodes;
foreach ( sort { $ccodes->{$a} cmp $ccodes->{$b} } keys %$ccodes ) {
    push @ccodes, { code => $_, description => $ccodes->{$_} };
}

# various
my $CGIextChoice = ('CSV');               # FIXME translation
my $CGIsepChoice = GetDelimiterChoices;

$template->param(
    categoryloop => \@patron_categories,
    itemtypes    => $itemtypes,
    locationloop => \@locations,
    ccodeloop    => \@ccodes,
    hassort1     => $hassort1,
    hassort2     => $hassort2,
    Bsort1       => $Bsort1,
    Bsort2       => $Bsort2,
    CGIextChoice => $CGIextChoice,
    CGIsepChoice => $CGIsepChoice,
);
output_html_with_http_headers $input, $cookie, $template->output;

sub calculate {
    my ( $linefield, $colfield, $process, $filters_hashref ) = @_;
    my @loopfooter;
    my @loopcol;
    my @loopline;
    my @looprow;
    my %globalline;
    my $grantotal = 0;

    # extract parameters
    my $dbh = C4::Context->dbh;

    # Filters
    # Checking filters
    #
    my @loopfilter;
    foreach my $filter ( keys %$filters_hashref ) {
        $filters_hashref->{$filter} =~ s/\*/%/;
    }

    #display
    @loopfilter = map {
        {
            crit   => $_,
            filter => $filters_hashref->{$_},
        }
    } sort keys %$filters_hashref;

    my $linesql = changeifreservestatus($linefield);
    my $colsql  = changeifreservestatus($colfield);

    #Initialization of cell values.....

    # preparing calculation
    my $strcalc = "(SELECT $linesql line, $colsql col, ";
    $strcalc .=
          ( $process == 1 ) ? " COUNT(*)  calculation"
        : ( $process == 2 ) ? "(COUNT(DISTINCT reserves.borrowernumber)) calculation"
        : ( $process == 3 ) ? "(COUNT(DISTINCT reserves.itemnumber)) calculation"
        : ( $process == 4 ) ? "(COUNT(DISTINCT reserves.biblionumber)) calculation"
        :                     '*';
    $strcalc .= "
        FROM (select * from reserves union select * from old_reserves) reserves
        LEFT JOIN borrowers USING (borrowernumber)
    ";
    $strcalc .= "LEFT JOIN biblio ON reserves.biblionumber=biblio.biblionumber "
        if ( $linefield =~ /^biblio\./ or $colfield =~ /^biblio\./ or any { $_ =~ /biblio/ } keys %$filters_hashref );
    $strcalc .= "LEFT JOIN items ON reserves.itemnumber=items.itemnumber "
        if ( $linefield =~ /^items\./ or $colfield =~ /^items\./ or any { $_ =~ /items/ } keys %$filters_hashref );

    my @sqlparams;
    my @sqlorparams;
    my @sqlor;
    my @sqlwhere;
    foreach my $filter ( keys %$filters_hashref ) {
        my $string;
        my $stringfield = $filter;
        $stringfield =~ s/\_[a-z_]+$//;
        if ( $filter =~ / / ) {
            $string = $stringfield;
        } elsif ( $filter =~ /_or/ ) {
            push @sqlor,       qq{( } . changeifreservestatus($filter) . " = ? ) ";
            push @sqlorparams, $$filters_hashref{$filter};
        } elsif ( $filter =~ /_endex$/ ) {
            $string = " $stringfield < ? ";
        } elsif ( $filter =~ /_end$/ ) {
            $string = " $stringfield <= ? ";
        } elsif ( $filter =~ /_begin$/ ) {
            $string = " $stringfield >= ? ";
        } else {
            $string = " $stringfield LIKE ? ";
        }
        if ($string) {
            push @sqlwhere,  $string;
            push @sqlparams, $$filters_hashref{$filter};
        }
    }

    $strcalc .= " WHERE " . join( " AND ", @sqlwhere )  if (@sqlwhere);
    $strcalc .= " AND (" . join( " OR ", @sqlor ) . ")" if (@sqlor);
    $strcalc .= " GROUP BY line, col )";
    my $dbcalc = $dbh->prepare($strcalc);
    push @loopfilter, { crit => 'SQL =', sql => 1, filter => $strcalc };
    @sqlparams = ( @sqlparams, @sqlorparams );
    $dbcalc->execute(@sqlparams);
    my $data = $dbcalc->fetchall_hashref( [qw(line col)] );
    my %cols_hash;

    foreach my $row ( keys %$data ) {
        push @loopline, $row;
        foreach my $col ( keys %{ $$data{$row} } ) {
            $$data{$row}{totalrow} += $$data{$row}{$col}{calculation};
            $grantotal += $$data{$row}{$col}{calculation};
            $cols_hash{$col} = 1;
        }
    }
    my $urlbase = "do_it=1&amp;" . join( "&amp;", map { "filter_$_=$$filters_hashref{$_}" } keys %$filters_hashref );
    foreach my $row ( sort @loopline ) {
        my @loopcell;

        #@loopcol ensures the order for columns is common with column titles
        # and the number matches the number of columns
        foreach my $col ( sort keys %cols_hash ) {
            push @loopcell, {
                value => ( $$data{$row}{$col}{calculation} or "" ),

                # url_complement=>($urlbase=~/&amp;$/?$urlbase."&amp;":$urlbase)."filter_$linefield=$row&amp;filter_$colfield=$col"
            };
        }
        push @looprow, {
            'rowtitle_display' => display_value( $linefield, $row ),
            'rowtitle'         => $row,
            'loopcell'         => \@loopcell,
            'totalrow'         => $$data{$row}{totalrow}
        };
    }
    for my $col ( sort keys %cols_hash ) {
        my $total = 0;
        foreach my $row (@loopline) {
            $total += $data->{$row}{$col}{calculation} if $data->{$row}{$col}{calculation};
        }
        push @loopfooter, { 'totalcol' => $total };
        push @loopcol, {
            'coltitle'       => $col,
            coltitle_display => display_value( $colfield, $col )
        };
    }

    # the header of the table
    $globalline{loopfilter} = \@loopfilter;

    # the core of the table
    $globalline{looprow} = \@looprow;
    $globalline{loopcol} = \@loopcol;

    # # the foot (totals by borrower type)
    $globalline{loopfooter} = \@loopfooter;
    $globalline{total}      = $grantotal;
    $globalline{line}       = $linefield;
    $globalline{column}     = $colfield;
    return [ ( \%globalline ) ];
}

sub display_value {
    my ( $crit, $value ) = @_;
    my $locations = {
        map { ( $_->{authorised_value} => $_->{lib} ) } Koha::AuthorisedValues->get_descriptions_by_koha_field(
            { frameworkcode => '', kohafield => 'items.location' }, { order_by => ['description'] }
        )
    };
    my $ccodes = {
        map { ( $_->{authorised_value} => $_->{lib} ) } Koha::AuthorisedValues->get_descriptions_by_koha_field(
            { frameworkcode => '', kohafield => 'items.ccode' }, { order_by => ['description'] }
        )
    };
    my $Bsort1 = GetAuthorisedValues("Bsort1");
    my $Bsort2 = GetAuthorisedValues("Bsort2");
    my $display_value =
          ( $crit =~ /ccode/ )    ? $ccodes->{$value}
        : ( $crit =~ /location/ ) ? $locations->{$value}
        : ( $crit =~ /itemtype/ ) ? Koha::ItemTypes->find($value)->translated_description
        : ( $crit =~ /branch/ )   ? Koha::Libraries->find($value)->branchname
        :                           $value;                                                 # default fallback
    if ( $crit =~ /sort1/ ) {
        foreach (@$Bsort1) {
            ( $value eq $_->{authorised_value} ) or next;
            $display_value = $_->{lib} and last;
        }
    } elsif ( $crit =~ /sort2/ ) {
        foreach (@$Bsort2) {
            ( $value eq $_->{authorised_value} ) or next;
            $display_value = $_->{lib} and last;
        }
    } elsif ( $crit =~ /category/ ) {
        my @patron_categories =
            Koha::Patron::Categories->search_with_library_limits( {}, { order_by => ['description'] } )->as_list;
        foreach my $patron_category (@patron_categories) {
            ( $value eq $patron_category->categorycode ) or next;
            $display_value = $patron_category->description and last;
        }
    }
    return $display_value;
}

sub changeifreservestatus {
    my ($field) = @_;
    return $field unless $field =~ /reservestatus/;

    # For reservestatus we return C- Cancelled, W- Waiting, F- Filled, P- Placed (or other like processing, transit etc.)
    return
        q|CASE WHEN cancellationdate IS NOT NULL THEN 'C' WHEN found='W' THEN 'W' WHEN found='F' THEN 'F' ELSE 'P' END|;
}
