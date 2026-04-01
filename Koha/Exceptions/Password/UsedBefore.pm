package Koha::Exceptions::Password::UsedBefore;

use Modern::Perl;

use Koha::Exception;

use Exception::Class (
    'Koha::Exceptions::Password::UsedBefore' => {
        isa         => 'Koha::Exception',
        description => 'Password has been used before',
    },
);

1;
