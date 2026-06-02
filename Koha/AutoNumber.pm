package Koha::AutoNumber;

# Copyright 2026 Open Fifth Ltd
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

=encoding UTF-8

=head1 NAME

Koha::AutoNumber - generic factory and base class for auto-incrementing identifier
generation

=head1 SYNOPSIS

    # Via a domain-specific adapter (preferred):
    my $gen = Koha::Patron::AutoNumber->new;

    # Or directly with explicit context:
    my $gen = Koha::AutoNumber->new({
        format_pref  => 'autoMemberNumFormat',
        counter_pref => 'autoMemberNumValue',
        db_source    => 'Borrower',
        db_column    => 'cardnumber',
    });

    # Inside a transaction:
    my $next = $gen->next_value($schema);

=head1 DESCRIPTION

A generic, context-aware strategy framework for generating unique sequential
identifiers.  The same strategies (Sequential, EAN-13, etc.) can serve any
domain — patron cardnumbers, item barcodes, or any other running identifier —
because the domain-specific details (which syspref holds the counter, which
table and column to query) are injected as constructor configuration rather
than hard-coded in the strategies themselves.

Domain adapters (e.g. L<Koha::Patron::AutoNumber>) supply the context; the
strategies only define how numbers are formatted and incremented.

=head2 Configuration keys

=over 4

=item * C<format_pref> — system preference that selects the active strategy
(e.g. C<autoMemberNumFormat>).

=item * C<counter_pref> — system preference used as the monotonic counter
(e.g. C<autoMemberNumValue>).  Selected C<FOR UPDATE> inside C<next_value>
to serialise concurrent callers.

=item * C<db_source> — DBIx::Class result source name for C<db_max>
(e.g. C<Borrower>).  Must be an internal constant; never accept this
from user input.

=item * C<db_column> — column within C<db_source> that holds the identifier
(e.g. C<cardnumber>).  Same caveat applies.

=back

=head2 Extending

To add a new strategy, create C<Koha::AutoNumber::YourStrategy>, inherit from
this class, and override C<_next_from($prev)> for the generation arithmetic
and C<db_max($schema)> if the format requires a narrower query (e.g. only
13-digit values for EAN-13).

=cut

use Modern::Perl;
use C4::Context;

my %strategies = (
    sequential => 'Koha::AutoNumber::Sequential',
    ean13      => 'Koha::AutoNumber::EAN13',
);

=head2 Class methods

=head3 new

    my $gen = Koha::AutoNumber->new(\%config);

Factory constructor.  Reads C<format_pref> to select the strategy subclass,
then blesses the full config into that class so every hook method has access
to the context.

=cut

sub new {
    my ( $class, $config ) = @_;
    my $format         = C4::Context->preference( $config->{format_pref} ) || 'sequential';
    my $strategy_class = $strategies{$format}                              || $strategies{sequential};

    # Lazy-load the strategy module to avoid a circular compile-time dependency:
    # the strategy subclasses declare 'use parent Koha::AutoNumber', so loading
    # them with a top-level 'use' would create a load-order loop.
    ( my $path = "$strategy_class.pm" ) =~ s{::}{/}g;
    require $path;

    return bless { %{$config} }, $strategy_class;
}

=head2 Instance methods

=head3 next_value

    my $id = $gen->next_value($schema);

Generates and permanently assigns the next identifier.  Must be called inside
an open transaction — it selects C<counter_pref> C<FOR UPDATE> to serialise
concurrent callers, then updates the counter to the newly issued value.

=cut

sub next_value {
    my ( $self, $schema ) = @_;

    my $pref_rs = $schema->resultset('Systempreference')->search(
        { variable => $self->{counter_pref} },
        { for      => 'update' },
    );
    my $pref    = $pref_rs->first;
    my $counter = ( $pref && defined $pref->value ) ? $pref->value + 0 : 0;

    my $floor  = $self->effective_floor($counter);
    my $db_max = $self->db_max($schema);
    my $prev   = $floor > $db_max ? $floor : $db_max;

    $self->validate_next( $prev + 1 );
    my $next = $self->_next_from($prev);

    $pref->update( { value => $next + 0 } ) if $pref;

    return $next;
}

=head3 peek

    my $suggestion = $gen->peek($schema);

Returns what the next identifier B<would> be without acquiring a lock or
updating the counter.  Safe to call outside a transaction.

Intended for pre-populating form fields so users can see the likely next
value before saving.  Because no lock is taken, two concurrent callers may
receive the same suggestion — the actual assigned identifier is always the
one returned by C<next_value> at save time.

=cut

sub peek {
    my ( $self, $schema ) = @_;

    my $row     = $schema->resultset('Systempreference')->find( { variable => $self->{counter_pref} } );
    my $counter = ( $row && defined $row->value ) ? $row->value + 0 : 0;

    my $floor  = $self->effective_floor($counter);
    my $db_max = $self->db_max($schema);
    my $prev   = $floor > $db_max ? $floor : $db_max;

    return $self->_next_from($prev);
}

=head3 db_max

    my $max = $self->db_max($schema);

Returns the highest purely-numeric value currently stored in the
configured result source column.  Strategies may override this to apply
a narrower filter (e.g. EAN-13 only considers exactly 13-digit values).

Uses a C<CAST(... AS SIGNED)> literal to ensure numeric rather than
lexicographic ordering for variable-length values.  C<db_column> is
interpolated into the literal because DBIx::Class does not abstract
C<CAST>; it comes from internal configuration, never from user input.

=cut

sub db_max {
    my ( $self,   $schema ) = @_;
    my ( $source, $column ) = @{$self}{qw(db_source db_column)};
    return $schema->resultset($source)->search(
        { $column => { -regexp => '^-?[0-9]+$' } },
        {
            select => [ \["MAX(CAST($column AS SIGNED))"] ],
            as     => ['max_val'],
        }
    )->get_column('max_val')->single // 0;
}

=head3 effective_floor

    my $floor = $self->effective_floor($counter);

Hook for adjusting the stored counter before comparing it against C<db_max>.
The base implementation returns C<$counter> unchanged.

=cut

sub effective_floor {
    my ( $self, $counter ) = @_;
    return $counter;
}

=head3 validate_next

    $self->validate_next($candidate);

Hook called after computing the candidate next value.  Should throw if the
value is not acceptable.  The base implementation is a no-op.

=cut

sub validate_next { }

=head3 _next_from

    my $formatted = $self->_next_from($prev);

Pure generation arithmetic: given the highest previously-issued value,
return the next identifier as a string.  The base implementation simply
increments by one and stringifies.  Strategies that require check digits or
specific formatting (e.g. EAN-13) override this method.

This is the primary extension point — strategies only need to override
C<_next_from> (and C<db_max> if the query must be narrowed), keeping
C<next_value> and C<peek> free of format-specific code.

=cut

sub _next_from {
    my ( $self, $prev ) = @_;
    return $self->format_value( $prev + 1 );
}

=head3 format_value

    my $str = $self->format_value($n);

Converts a numeric identifier to its final string form.  The base
implementation stringifies the integer without modification.

=cut

sub format_value {
    my ( $self, $n ) = @_;
    return "$n";
}

1;
