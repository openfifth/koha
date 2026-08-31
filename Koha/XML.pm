package Koha::XML;

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

use XML::LibXML;

=head1 NAME

Koha::XML - Helpers for safely parsing untrusted XML

=head1 DESCRIPTION

Provides a hardened C<XML::LibXML> parser and a pre-parse check for
untrusted XML bodies, to guard against XXE (file read, SSRF) and
internal-entity based DoS.

=head1 METHODS

=head2 safe_xml_parser

    my $parser = safe_xml_parser();

Hardened XML::LibXML parser: entity expansion, external DTD loading,
and network access disabled, to block XXE (file read, SSRF).

Doesn't stop internal-entity DoS alone - see C<unsafe_xml_body>.

=cut

sub safe_xml_parser {
    my $parser = XML::LibXML->new();
    $parser->expand_entities(0);
    $parser->load_ext_dtd(0);
    $parser->no_network(1);
    return $parser;
}

=head2 unsafe_xml_body

    my $bool = unsafe_xml_body($xml);

True if C<$xml> has a DOCTYPE, or a NUL byte (used to hide a DOCTYPE
in UTF-16/32-encoded bodies).

=cut

sub unsafe_xml_body {
    my ($xml) = @_;
    return 0 unless defined $xml;
    return 1 if $xml =~ /\x00/;
    return 1 if $xml =~ /<!DOCTYPE/i;
    return 0;
}

1;
