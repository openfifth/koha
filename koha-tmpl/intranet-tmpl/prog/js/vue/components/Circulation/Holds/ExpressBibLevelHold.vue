<template>
    <div class="express-bib-level-hold card">
        <div class="card-body">
            <h2 class="card-title">{{ biblio.title }}</h2>

            <HoldabilityShield
                :biblio-id="biblio.biblio_id"
                :patron-id="patron.patron_id"
                :pickup-library-id="formData.pickup_library_id"
                @eligibility="handleEligibility"
                @blocked="handleBlocked"
            />

            <div v-if="errorMessage" class="alert alert-danger">
                {{ errorMessage }}
            </div>

            <form @submit.prevent="handleSubmit">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <FormElement
                                :resource="formData"
                                :attr="pickupLibraryField"
                                :index="0"
                            />
                        </li>
                        <li
                            v-for="(attr, index) in restFields"
                            :key="attr.name"
                        >
                            <FormElement
                                :resource="formData"
                                :attr="attr"
                                :index="index + 1"
                            />
                        </li>
                    </ol>
                </fieldset>

                <fieldset v-if="canSubmit" class="action">
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
                        {{ overridable ? $__("Override and place hold") : $__("Place hold") }}
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
import { computed, reactive, ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import FormElement from "../../FormElement.vue";
import Toast from "../../Elements/Toast.vue";
import HoldabilityShield from "./HoldabilityShield.vue";
import { useHoldOverrideConfirmation } from "../../../composables/hold-override-confirmation.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "ExpressBibLevelHold",
    components: { FormElement, Toast, HoldabilityShield },
    props: {
        biblio: { type: Object, required: true }, // { biblio_id, title }
        patron: { type: Object, required: true }, // { patron_id, library_id, branchname }
    },
    setup(props) {
        const { requestHoldOverride } = useHoldOverrideConfirmation();

        // Set by HoldabilityShield.vue's @eligibility/@blocked events -
        // HoldabilityShield only reports what it found, it doesn't decide
        // anything about the form itself.
        const available = ref(false);
        const overridable = ref(false);
        const blockedReasons = ref([]);

        // Whether the "Place hold" button at the bottom of the form has
        // anything to do at all - either place the hold directly, or open
        // the override confirmation first. There's only ever one button;
        // this is the one thing gating whether it's shown.
        const canSubmit = computed(() => available.value || overridable.value);

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

        // Always rendered, even while blocked - it's the one field that
        // can actually resolve a pickup-library-specific block
        // (cannot_be_transferred, library_not_pickup_location).
        const pickupLibraryField = computed(() => ({
            name: "pickup_library_id",
            type: "component",
            label: $__("Pickup library"),
            required: true, // reserves.branchcode is NOT NULL in the DB
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
        }));

        // Always rendered, even while blocked - the override flow is
        // triggered by this same form's submit button (see handleSubmit),
        // so hiding these fields while blocked only ever discarded
        // whatever the user had already typed, it never actually gated
        // anything.
        const restFields = computed(() => [
            { name: "expiration_date", type: "date", label: $__("Expires") },
            {
                name: "notes",
                type: "textarea",
                label: $__("Notes"),
                textAreaRows: 3,
            },
        ]);

        const handleEligibility = () => {
            available.value = true;
            overridable.value = false;
        };

        const handleBlocked = ({ blockers, overridable: canOverride }) => {
            available.value = false;
            overridable.value = canOverride;
            blockedReasons.value = blockers;
        };

        // The single entry point for the "Place hold" button: place the
        // hold directly when it's already available, otherwise - if
        // there's an overridable block - show the override confirmation
        // first and only place the hold if the user accepts it. What
        // confirming means here (retry the placement with those codes) is
        // this component's job; HoldabilityShield only ever tells us what
        // was blocked.
        const handleSubmit = () => {
            if (available.value) {
                placeHold();
            } else if (overridable.value) {
                requestHoldOverride(blockedReasons.value).then(codes => {
                    if (codes) placeHold(codes);
                });
            }
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

        return {
            canSubmit,
            pickupLibraryField,
            restFields,
            formData,
            placing,
            holdPlaced,
            errorMessage,
            handleEligibility,
            handleBlocked,
            handleSubmit,
            toastVisible,
            toastMessage,
            overridable
        };
    },
};
</script>

<style></style>
