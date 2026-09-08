<template>
    <div class="express-bib-level-hold card">
        <div class="card-body">
            <div class="d-flex justify-content-between align-items-start">
                <h2 class="card-title">{{ biblio.title }}</h2>
                <button
                    v-if="showMoreOptions"
                    type="button"
                    class="btn btn-link"
                    @click="goToMoreOptions"
                >
                    {{ $__("More options") }}
                </button>
            </div>

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

                <fieldset v-if="checked" class="action">
                    <span
                        class="submit-tooltip"
                        :title="canSubmit ? null : disabledReason"
                    >
                        <button
                            type="submit"
                            class="btn btn-primary"
                            :disabled="holdPlaced || !canSubmit"
                        >
                            <span
                                v-if="placing"
                                class="spinner-border spinner-border-sm"
                                aria-hidden="true"
                            ></span>
                            {{
                                overridable
                                    ? $__("Override and place hold")
                                    : $__("Place hold")
                            }}
                        </button>
                    </span>
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
import { useRoute, useRouter } from "vue-router";
import FormElement from "../../FormElement.vue";
import Toast from "../../Elements/Toast.vue";
import HoldabilityShield from "./HoldabilityShield.vue";
import { useHoldSubmission } from "../../../composables/hold-submission.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "ExpressBibLevelHold",
    components: { FormElement, Toast, HoldabilityShield },
    props: {
        biblio: { type: Object, required: true }, // { biblio_id, title }
        patron: { type: Object, required: true }, // { patron_id, library_id, library: { name } }
        // Hidden when this component is rendered as the Record panel of
        // GranularItemHold.vue - that screen's own Hold type switch is
        // already the same option, and it's already selected.
        showMoreOptions: { type: Boolean, default: true },
    },
    setup(props) {
        const route = useRoute();
        const router = useRouter();
        const { placing, holdPlaced, errorMessage, submit } =
            useHoldSubmission();

        // Pure navigation to the granular hold screen - PlaceHold.vue (the
        // parent route component) reads this same ?view= query flag to
        // decide whether to render this component or GranularItemHold.vue,
        // so the biblio/patron it already loaded are reused rather than
        // re-fetched.
        const goToMoreOptions = () => {
            router.push({
                name: "PlaceHold",
                query: { ...route.query, view: "granular" },
            });
        };

        // Set by HoldabilityShield.vue's @eligibility/@blocked events -
        // HoldabilityShield only reports what it found, it doesn't decide
        // anything about the form itself.
        const available = ref(false);
        const overridable = ref(false);
        const blockedReasons = ref([]);
        // True from the first eligibility/blocked result onward - lets the
        // button stay hidden during the initial skeleton (nothing checked
        // yet), but never re-hide itself once something has been checked,
        // even across a background re-check.
        const checked = ref(false);

        // Whether the "Place hold" button at the bottom of the form has
        // anything to do at all - either place the hold directly, or open
        // the override confirmation first. When false, the button is
        // still shown (once checked) but disabled, with disabledReason
        // explaining why via a tooltip - see the template.
        const canSubmit = computed(() => available.value || overridable.value);

        // Native title tooltips don't fire on a disabled button - Bootstrap
        // sets pointer-events: none on .btn:disabled, which suppresses
        // hover on the button itself. The title lives on the wrapping
        // <span> in the template instead, which isn't affected.
        const disabledReason = computed(() =>
            blockedReasons.value.map(r => r.label).join("\n")
        );

        const formData = reactive({
            pickup_library_id: props.patron.library_id,
            expiration_date: null,
            notes: "",
        });

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
                    value: props.patron.library?.name,
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
            checked.value = true;
        };

        const handleBlocked = ({ blockers, overridable: canOverride }) => {
            available.value = false;
            overridable.value = canOverride;
            blockedReasons.value = blockers;
            checked.value = true;
        };

        // The single entry point for the "Place hold" button: hand off to
        // useHoldSubmission, which decides whether to place the hold
        // directly or open the override confirmation first, then show the
        // toast and redirect once a hold actually comes back. What
        // confirming means here (retry the placement with those codes) is
        // useHoldSubmission's job; HoldabilityShield only ever tells us what
        // was blocked.
        const handleSubmit = () => {
            const result = submit(
                available.value,
                overridable.value,
                blockedReasons.value,
                {
                    patron_id: props.patron.patron_id,
                    biblio_id: props.biblio.biblio_id,
                    pickup_library_id: formData.pickup_library_id,
                    expiration_date: formData.expiration_date || undefined,
                    notes: formData.notes || undefined,
                }
            );
            // submit() resolves with undefined when the override
            // confirmation was cancelled - nothing to redirect for.
            if (result) {
                result
                    .then(hold => {
                        if (!hold) return;
                        toastMessage.value = $__("Queue position: #%s").format(
                            hold.priority
                        );
                        toastVisible.value = true;
                        setTimeout(() => {
                            window.location = `/cgi-bin/koha/members/moremember.pl?borrowernumber=${props.patron.patron_id}#holds`;
                        }, 1500);
                    })
                    // errorMessage is already surfaced reactively by
                    // useHoldSubmission - this only exists to keep the
                    // rejection from useHoldSubmission's rethrow (there for
                    // callers who do want to chain on it) from surfacing as
                    // an unhandled promise rejection here.
                    .catch(() => {});
            }
        };

        return {
            canSubmit,
            checked,
            goToMoreOptions,
            disabledReason,
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
            overridable,
        };
    },
};
</script>

<style></style>
