use Modern::Perl;
use Koha::Installer::Output qw(say_warning say_success say_info);

return {
    bug_number  => "43695",
    description => "Add system preferences ISO18626AgencyId and ISO18626AgencyIdType",
    up          => sub {
        my ($args) = @_;
        my ( $dbh, $out ) = @$args{qw(dbh out)};

        $dbh->do(
            q{
                INSERT IGNORE INTO systempreferences (variable, value)
                VALUES ('ISO18626AgencyId', ''), ('ISO18626AgencyIdType', 'ISIL')
            }
        );

        say $out "Added new system preference 'ISO18626AgencyId'";
        say $out "Added new system preference 'ISO18626AgencyIdType'";
    },
};
