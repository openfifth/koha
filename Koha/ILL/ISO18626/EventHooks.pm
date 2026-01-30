package Koha::ILL::ISO18626::EventHooks;

# Copyright Open Fifth 2026
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

use Koha::Events;

#FIXME: This works, but lacks the ISO18626 relevant data e.g. status info delivery date, message info note.
Koha::Events::subscribe('Koha::Hold', 'create', sub {
        my ($hold) = @_;

        # my $iso18626_request = $hold->iso18626_request;

        # return unless $iso18626_request;

        # if ($iso18626_request->status eq 'RequestReceived'){
        #     $iso18626_request->progress_request(
        #         'supplyingAgency',
        #         {
        #             'expectedDeliveryDate' => undef,
        #             'messageInfoNote' => "my message",
        #             'status' => 'ExpectToSupply'
        #         }
        #     );
        # }

        return;
    });

1;
