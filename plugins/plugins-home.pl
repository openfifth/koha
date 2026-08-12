#!/usr/bin/perl

# Copyright 2010 Kyle M Hall <kyle.m.hall@gmail.com>
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

use Koha::Plugins;
use Koha::Plugins::Search;
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::Context;

my $plugins_enabled = C4::Context->config("enable_plugins");

my $input         = CGI->new;
my $method        = $input->param('method');
my $plugin_search = $input->param('plugin-search');

my ( $template, $borrowernumber, $cookie ) = get_template_and_user(
    {
        template_name => ($plugins_enabled) ? "plugins/plugins-home.tt" : "plugins/plugins-disabled.tt",
        query         => $input,
        type          => "intranet",
        flagsrequired => { plugins => '*' },
    }
);

if ($plugins_enabled) {

    $template->param(
        koha_version => C4::Context->preference("Version"),
        method       => $method,
    );

    my ( $plugins, $failures ) = Koha::Plugins->new()->GetPlugins(
        {
            method => $method,
            all    => 1,
            errors => 1
        }
    );

    $template->param( plugins            => [ @$plugins, @$failures ] );
    $template->param( plugins_restricted => C4::Context->config('plugins_restricted') );

    $template->param( can_search => C4::Context->config('plugin_store_url') ? 1 : 0 );

    if ($plugin_search) {
        my ( $results, $errors ) = Koha::Plugins::Search->search($plugin_search);

        $template->param(
            search_results => $results,
            search_errors  => $errors,
            search_term    => $plugin_search,
        );
    }
}

output_html_with_http_headers( $input, $cookie, $template->output );
