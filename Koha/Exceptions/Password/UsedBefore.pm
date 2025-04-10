package Koha::Exceptions::Password::UsedBefore;

use Modern::Perl;

use Exception::Class (
    'Koha::Exceptions::Password::UsedBefore' => {
        isa => 'Koha::Exceptions::Exception',
        description => 'Password has been used before',
    },
);

1;
