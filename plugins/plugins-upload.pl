#!/usr/bin/perl

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
use Mojo::UserAgent;
use File::Temp;

use C4::Context;
use C4::Auth   qw( get_template_and_user );
use C4::Output qw( output_html_with_http_headers );
use C4::Members;
use Koha::Logger;
use Koha::Plugins;
use Koha::Plugins::Install;

my $plugins_enabled    = C4::Context->config("enable_plugins");
my $plugins_restricted = C4::Context->config("plugins_restricted");
my $plugins_restart    = C4::Context->config("plugins_restart");

my $input          = CGI->new;
my $uploadlocation = $input->param('uploadlocation');

my ( $template, $loggedinuser, $cookie ) = get_template_and_user(
    {
        template_name => ( !$plugins_enabled || $plugins_restricted && !$uploadlocation )
        ? 'plugins/plugins-disabled.tt'
        : 'plugins/plugins-upload.tt',
        query         => $input,
        type          => "intranet",
        flagsrequired => { plugins => 'manage' },
    }
);
$template->param( plugins_restart => $plugins_restart );

# Early exist if uploads are not enabled direct upload attempted when uploads are restricted
if ( !$plugins_enabled ) {
    output_html_with_http_headers $input, $cookie, $template->output;
    exit;
} elsif ( $plugins_restricted && !$uploadlocation ) {
    $template->param( plugins_restricted => $plugins_restricted );
    output_html_with_http_headers $input, $cookie, $template->output;
    exit;
}

my $uploadfilename = $input->param('uploadfile');
my $uploadfile     = $input->upload('uploadfile');
my $repo_url       = $input->param('repo_url');      # only present for search-result-driven installs
my $op             = $input->param('op') || q{};

my ( $tempfile, $tfh );
my %errors;

if ( ( $op eq 'cud-Upload' ) && ( $uploadfile || $uploadlocation ) ) {
    my $dirname = File::Temp::tempdir( CLEANUP => 1 );

    my $filesuffix;
    $filesuffix = $1 if $uploadfilename =~ m/(\..+)$/i;
    ( $tfh, $tempfile ) = File::Temp::tempfile( SUFFIX => $filesuffix, UNLINK => 1 );

    $errors{'NOWRITETEMP'} = 1 unless ( -w $dirname );

    if ($uploadlocation) {
        my $ua = Mojo::UserAgent->new( max_redirects => 5 );
        my $tx = $ua->get($uploadlocation);
        $tx->result->content->asset->move_to($tempfile);
    } elsif ($uploadfile) {
        while (<$uploadfile>) {
            print $tfh $_;
        }
        close $tfh;
    } else {
        $errors{'EMPTYUPLOAD'} = 1;
    }

    unless (%errors) {
        my ( $ok, $result ) = Koha::Plugins::Install->install(
            {
                kpz_path => $tempfile,
                filename => $uploadfilename,
                repo_url => $repo_url,
            }
        );
        %errors = %$result unless $ok;
    }

    $template->param( ERRORS => [ \%errors ] ) if %errors;
} elsif ( ( $op eq 'cud-Upload' ) && !$uploadfile && !$uploadlocation ) {
    warn "Problem uploading file or no file uploaded.";
}

if ( ( $uploadfile || $uploadlocation ) && !%errors && !$template->param('ERRORS') ) {
    print $input->redirect("/cgi-bin/koha/plugins/plugins-home.pl");
} else {
    output_html_with_http_headers $input, $cookie, $template->output;
}

exit;
