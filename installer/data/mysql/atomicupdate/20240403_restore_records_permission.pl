#!/usr/bin/perl
# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;
use C4::Context;

use Koha::Database;

my $dbh = C4::Context->dbh;

# Add restore_records permission to userflags
$dbh->do(q{
    INSERT INTO userflags (bit, flag, flagdesc, defaulton)
    SELECT 32, 'restore_records', 'Restore deleted records', 0
    FROM dual
    WHERE NOT EXISTS (
        SELECT 1 FROM userflags WHERE flag = 'restore_records'
    )
});

# Add restore_records permission to permissions
$dbh->do(q{
    INSERT INTO permissions (module_bit, code, description)
    SELECT 32, 'restore_records', 'Restore deleted records'
    FROM dual
    WHERE NOT EXISTS (
        SELECT 1 FROM permissions WHERE code = 'restore_records'
    )
});

print "Upgrade done (Add restore_records permission)\n";