<template>
    <div class="express-bib-level-hold card">
        <!-- Skeleton: shown until the one holdability call resolves for the
             first time (or immediately, if nothing is cached yet). -->
        <div v-if="!initialized" class="card-body placeholder-glow">
            <p class="placeholder col-7 placeholder-lg"></p>
            <p class="placeholder col-4"></p>
            <p class="placeholder col-9"></p>
            <span class="placeholder col-3"></span>
            <span class="placeholder col-3"></span>
        </div>

        <div v-else class="card-body">
            <h2 class="card-title">{{ biblio.title }}</h2>

            <p class="text-muted">
                {{
                    $__("%s total, %s holdable · Queue position: #%s").format(
                        holdability.items.total,
                        holdability.items.holdable,
                        holdability.prospective_priority
                    )
                }}
            </p>

            <div v-if="holdability.hold_fee" class="alert alert-info py-2">
                {{
                    $__("A fee of %s applies to this hold.").format(
                        holdability.hold_fee
                    )
                }}
            </div>

            <!-- Blockers, rendered inline rather than through the global
                 Dialog: a list of reasons doesn't fit the single message
                 string Dialog.setError()/setWarning() expects. -->
            <div v-if="!holdability.available" class="alert alert-danger">
                <p class="mb-1">
                    {{ $__("This hold cannot be placed:") }}
                </p>
                <ul class="mb-2">
                    <li v-for="b in holdability.blockers" :key="b.code">
                        {{ blockerLabel(b.code) }}
                    </li>
                </ul>
                <button
                    v-if="canOverride"
                    type="button"
                    class="btn btn-warning btn-sm"
                    @click="openOverrideModal"
                >
                    {{ $__("Override") }}
                </button>
            </div>

            <div v-else-if="errorMessage" class="alert alert-danger">
                {{ errorMessage }}
            </div>

            <!-- Same fieldset/ol/li shape ResourceFormSave.vue renders its own
                 fields in (that file's default, non-tabs/accordion branch),
                 so this form picks up the same global .rows styling as every
                 other form in the staff interface, Vue or legacy. -->
            <form v-if="holdability.available" @submit.prevent="placeHold()">
                <fieldset class="rows">
                    <ol>
                        <li
                            v-for="(attr, index) in formFields"
                            :key="attr.name"
                        >
                            <FormElement
                                :resource="formData"
                                :attr="attr"
                                :index="index"
                            />
                        </li>
                    </ol>
                </fieldset>

                <fieldset class="action">
                    <button
                        type="submit"
                        class="btn btn-primary"
                        :disabled="holdPlaced"
                    >
                        <span
                            v-if="placing"
                            class="spinner-border spinner-border-sm"
                            aria-hidden="true"
                        ></span>
                        {{ $__("Place hold") }}
                    </button>
                </fieldset>
            </form>
        </div>

        <Toast
            v-model="toastVisible"
            :title="$__('Hold placed')"
            :message="toastMessage"
        />
    </div>
</template>

<script>
import { computed, inject, onMounted, reactive, ref, watch } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import FormElement from "../../FormElement.vue";
import Toast from "../../Elements/Toast.vue";
import { $__ } from "@koha-vue/i18n";

// Human-readable text for every code Koha::*::Availability::Hold can
// produce (api/v1/swagger/definitions/availability_reason.yaml). Kept as a
// label lookup only - which codes are override-able comes from the API's
// own `overridable` flag on each reason, not from anything here.
const BLOCKER_LABELS = {
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

export default {
    name: "ExpressBibLevelHold",
    components: { FormElement, Toast },
    props: {
        biblio: { type: Object, required: true }, // { biblio_id, title }
        patron: { type: Object, required: true }, // { patron_id, library_id, branchname }
    },
    setup(props) {
        const mainStore = inject("mainStore");
        const holdsStore = inject("holdsStore");
        const { loading, loaded, setError } = mainStore;

        const initialized = ref(false);
        const holdability = ref(null);

        // FormElement writes into this directly (v-model="resource[attr.name]"),
        // keyed by the same field names the POST /holds body expects.
        const formData = reactive({
            pickup_library_id: props.patron.library_id,
            expiration_date: null,
            notes: "",
        });

        const placing = ref(false);
        const holdPlaced = ref(false);
        const errorMessage = ref(null);

        const toastVisible = ref(false);
        const toastMessage = ref("");

        // Same resourceAttrs shape ResourceFormSave.vue passes to FormElement.
        // Pickup library isn't one of FormElement's built-in field types - it's
        // a server-searched, lazily-loaded select, not a plain list of options
        // known up front - so it goes through the same 'component' escape
        // hatch the 'vendor' and 'date' types are themselves built on
        // (FormElement.vue's identifyAndImportComponent), pointing at
        // PickupLibrarySelect.vue instead of a built-in wrapper. A computed,
        // not a static list, since the biblio/patron it needs come from props
        // that can change without remounting this component.
        const formFields = computed(() => [
            {
                name: "pickup_library_id",
                type: "component",
                label: $__("Pickup library"),
                componentPath:
                    "@koha-vue/components/Circulation/Holds/PickupLibrarySelect.vue",
                componentProps: {
                    biblioId: { type: "string", value: props.biblio.biblio_id },
                    patronId: { type: "string", value: props.patron.patron_id },
                    defaultLibraryId: {
                        type: "string",
                        value: props.patron.library_id,
                    },
                    defaultLibraryName: {
                        type: "string",
                        value: props.patron.branchname,
                    },
                },
            },
            { name: "expiration_date", type: "date", label: $__("Expires") },
            {
                name: "notes",
                type: "textarea",
                label: $__("Notes"),
                textAreaRows: 3,
            },
        ]);

        const canOverride = computed(() => {
            if (!holdability.value || holdability.value.available) return false;
            return (
                holdsStore.sysprefs.AllowHoldPolicyOverride &&
                holdability.value.blockers.every(b => b.overridable)
            );
        });

        const blockerLabel = code => BLOCKER_LABELS[code] || code;

        const fetchHoldability = background => {
            if (!background) loading();

            return APIClient.circulation.holdability
                .biblio(props.biblio.biblio_id, {
                    patron_id: props.patron.patron_id,
                    pickup_library_id: formData.pickup_library_id,
                })
                .then(
                    result => {
                        holdsStore.setExpressCache(
                            props.biblio.biblio_id,
                            props.patron.patron_id,
                            result
                        );
                        holdability.value = result;
                        initialized.value = true;
                        if (!background) loaded();
                    },
                    error => {
                        if (!background) {
                            loaded();
                            setError(error);
                        }
                    }
                );
        };

        const load = () => {
            const cached = holdsStore.getExpressCache(
                props.biblio.biblio_id,
                props.patron.patron_id
            );
            if (cached) {
                holdability.value = cached.holdability;
                initialized.value = true;
                fetchHoldability(true); // refresh in the background
            } else {
                initialized.value = false;
                fetchHoldability(false);
            }
        };

        const openOverrideModal = () => {
            const codes = holdability.value.blockers.map(b => b.code);
            mainStore.setConfirmationDialog(
                {
                    title: $__("Override required"),
                    message:
                        "<ul>" +
                        holdability.value.blockers
                            .map(b => `<li>${blockerLabel(b.code)}</li>`)
                            .join("") +
                        "</ul>",
                    accept_label: $__("Override"),
                    cancel_label: $__("Cancel"),
                },
                () => placeHold(codes)
            );
        };

        const placeHold = (overrides = []) => {
            placing.value = true;
            errorMessage.value = null;
            holdPlaced.value = true; // optimistic: lock the form immediately

            return APIClient.circulation.holds
                .create(
                    {
                        patron_id: props.patron.patron_id,
                        biblio_id: props.biblio.biblio_id,
                        pickup_library_id: formData.pickup_library_id,
                        expiration_date: formData.expiration_date || undefined,
                        notes: formData.notes || undefined,
                    },
                    overrides
                )
                .then(
                    hold => {
                        placing.value = false;
                        toastMessage.value = $__("Queue position: #%s").format(
                            hold.priority
                        );
                        toastVisible.value = true;
                        setTimeout(() => {
                            window.location = `/cgi-bin/koha/members/moremember.pl?borrowernumber=${props.patron.patron_id}#holds`;
                        }, 1500);
                    },
                    error => {
                        // Roll back the optimistic lock - nothing was placed.
                        placing.value = false;
                        holdPlaced.value = false;
                        errorMessage.value = error.message || error;
                    }
                );
        };

        onMounted(load);
        watch(() => props.patron.patron_id, load);

        return {
            initialized,
            holdability,
            formFields,
            formData,
            placing,
            holdPlaced,
            errorMessage,
            canOverride,
            blockerLabel,
            openOverrideModal,
            placeHold,
            toastVisible,
            toastMessage,
        };
    },
};
</script>

<style></style>
