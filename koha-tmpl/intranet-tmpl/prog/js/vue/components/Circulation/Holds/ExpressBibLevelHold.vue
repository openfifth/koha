<template>
    <div class="express-bib-level-hold card">
        <div class="card-body">
            <h2 class="card-title">{{ biblio.title }}</h2>

            <HoldabilityShield
                :biblio-id="biblio.biblio_id"
                :patron-id="patron.patron_id"
                :pickup-library-id="formData.pickup_library_id"
                @eligibility="available = true"
                @blocked="available = false"
                @override-requested="handleOverrideRequested"
            />

            <div v-if="errorMessage" class="alert alert-danger">
                {{ errorMessage }}
            </div>

            <form @submit.prevent="placeHold()">
                <fieldset class="rows">
                    <ol>
                        <li>
                            <FormElement
                                :resource="formData"
                                :attr="pickupLibraryField"
                                :index="0"
                            />
                        </li>
                        <template v-if="available">
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
                        </template>
                    </ol>
                </fieldset>

                <fieldset v-if="available" class="action">
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
import { computed, reactive, ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import FormElement from "../../FormElement.vue";
import Toast from "../../Elements/Toast.vue";
import HoldabilityShield from "./HoldabilityShield.vue";
import { useMainStore } from "../../../stores/main.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "ExpressBibLevelHold",
    components: { FormElement, Toast, HoldabilityShield },
    props: {
        biblio: { type: Object, required: true }, // { biblio_id, title }
        patron: { type: Object, required: true }, // { patron_id, library_id, branchname }
    },
    setup(props) {
        const { setConfirmationDialog } = useMainStore();

        // Set by HoldabilityShield.vue's @eligibility/@blocked events.
        const available = ref(false);

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

        // Only rendered once the hold is actually placeable.
        const restFields = computed(() => [
            { name: "expiration_date", type: "date", label: $__("Expires") },
            {
                name: "notes",
                type: "textarea",
                label: $__("Notes"),
                textAreaRows: 3,
            },
        ]);

        // HoldabilityShield only tells us what's blocking the hold - asking
        // the user to confirm the override, and what confirming means here
        // (retry the placement with those codes), is this component's job.
        const handleOverrideRequested = reasons => {
            setConfirmationDialog(
                {
                    title: $__("Override required"),
                    message:
                        "<ul>" +
                        reasons.map(r => `<li>${r.label}</li>`).join("") +
                        "</ul>",
                    accept_label: $__("Override"),
                    cancel_label: $__("Cancel"),
                },
                () => placeHold(reasons.map(r => r.code))
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

        return {
            available,
            pickupLibraryField,
            restFields,
            formData,
            placing,
            holdPlaced,
            errorMessage,
            handleOverrideRequested,
            placeHold,
            toastVisible,
            toastMessage,
        };
    },
};
</script>

<style></style>
