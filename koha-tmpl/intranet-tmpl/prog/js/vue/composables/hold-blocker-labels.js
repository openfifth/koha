import { $__ } from "@koha-vue/i18n";

// Human-readable text for every code Koha::*::Availability::Hold can
// produce (api/v1/swagger/definitions/availability_reason.yaml). Kept as a
// label lookup only - which codes are override-able comes from the API's
// own `overridable` flag on each reason, not from anything here. Shared
// between HoldabilityShield.vue (biblio-level checks) and GranularItemHold.vue
// (per-item checks) so the two don't carry separate copies of this table.
export const BLOCKER_LABELS = {
    age_restricted: $__("This item is age restricted"),
    already_possession: $__("The patron already has this item checked out"),
    bad_address: $__("The patron has an incomplete address"),
    branch_not_in_hold_group: $__(
        "The pickup library is not in the record's hold group"
    ),
    cannot_be_transferred: $__(
        "This item cannot be transferred to the pickup library"
    ),
    cannot_reserve_from_other_branches: $__(
        "This library only allows holds on its own items"
    ),
    card_lost: $__("The patron's card has been reported lost"),
    damaged: $__("This item is damaged"),
    debt_limit: $__("The patron has too much debt to place a hold"),
    expired: $__("The patron's card has expired"),
    hold_limit: $__("The patron has reached their hold limit"),
    item_already_on_hold: $__("The patron already has a hold on this item"),
    library_not_pickup_location: $__(
        "This library is not a valid pickup location"
    ),
    no_item_available: $__("No item on this record can fill a hold"),
    no_items: $__("This record has no items"),
    no_reserves_allowed: $__("Holds are not allowed on this item"),
    not_reservable: $__("This item cannot be held"),
    pickup_not_in_hold_group: $__(
        "The pickup library is not in this item's hold group"
    ),
    recall: $__("This item has an active recall"),
    restricted: $__("The patron's account is restricted"),
    too_many_holds_for_this_record: $__(
        "The patron already has the maximum holds on this record"
    ),
    too_many_reserves: $__("The patron has reached their total hold limit"),
    too_many_reserves_today: $__("The patron has reached today's hold limit"),
};

export const blockerLabel = code => BLOCKER_LABELS[code] || code;
