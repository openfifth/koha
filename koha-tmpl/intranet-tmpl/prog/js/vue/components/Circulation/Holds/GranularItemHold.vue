<template>
    <div class="granular-item-hold card">
        <div class="card-body">
            <h2 class="card-title">{{ biblio.title }}</h2>

            <fieldset class="hold-type">
                <label>{{ $__("Hold type") }}: </label>
                <label class="radio-inline">
                    <input
                        v-model="holdType"
                        type="radio"
                        name="hold_type"
                        value="record"
                    />
                    {{ $__("Record") }}
                </label>
                <label v-if="showItemGroupOption" class="radio-inline">
                    <input
                        v-model="holdType"
                        type="radio"
                        name="hold_type"
                        value="item_group"
                    />
                    {{ $__("Item group") }}
                </label>
                <label class="radio-inline">
                    <input
                        v-model="holdType"
                        type="radio"
                        name="hold_type"
                        value="item"
                    />
                    {{ $__("Item") }}
                </label>
            </fieldset>

            <!-- Record: no new logic needed for this hold type, it's the
                 same form Express already offers. Its own "More options"
                 button is hidden here - the Hold type switch above is
                 already that same option, and it's already selected. -->
            <ExpressBibLevelHold
                v-if="holdType === 'record'"
                :biblio="biblio"
                :patron="patron"
                :show-more-options="false"
            />

            <!-- Item group -->
            <div v-else-if="holdType === 'item_group'" class="item-group-panel">
                <div class="mb-3">
                    <label for="item-group-select"
                        >{{ $__("Item group") }}:
                    </label>
                    <select
                        id="item-group-select"
                        v-model="selectedGroupId"
                        class="form-control"
                    >
                        <option :value="null" disabled>
                            {{ $__("Select an item group") }}
                        </option>
                        <option
                            v-for="group in itemGroups"
                            :key="group.item_group_id"
                            :value="group.item_group_id"
                        >
                            {{ group.description }}
                        </option>
                    </select>
                </div>

                <template v-if="selectedGroupId">
                    <HoldabilityShield
                        :biblio-id="biblio.biblio_id"
                        :patron-id="patron.patron_id"
                        :pickup-library-id="groupFormData.pickup_library_id"
                        @eligibility="handleGroupEligibility"
                        @blocked="handleGroupBlocked"
                    />

                    <div v-if="groupErrorMessage" class="alert alert-danger">
                        {{ groupErrorMessage }}
                    </div>

                    <form @submit.prevent="handleGroupSubmit">
                        <fieldset class="rows">
                            <ol>
                                <li>
                                    <FormElement
                                        :resource="groupFormData"
                                        :attr="pickupLibraryField"
                                        :index="0"
                                    />
                                </li>
                                <li
                                    v-for="(attr, index) in extraHoldFields"
                                    :key="attr.name"
                                >
                                    <FormElement
                                        :resource="groupFormData"
                                        :attr="attr"
                                        :index="index + 1"
                                    />
                                </li>
                            </ol>
                        </fieldset>

                        <fieldset v-if="groupChecked" class="action">
                            <span
                                class="submit-tooltip"
                                :title="
                                    groupCanSubmit ? null : groupDisabledReason
                                "
                            >
                                <button
                                    type="submit"
                                    class="btn btn-primary"
                                    :disabled="
                                        groupHoldPlaced || !groupCanSubmit
                                    "
                                >
                                    <span
                                        v-if="groupPlacing"
                                        class="spinner-border spinner-border-sm"
                                        aria-hidden="true"
                                    ></span>
                                    {{
                                        groupOverridable
                                            ? $__("Override and place hold")
                                            : $__("Place hold")
                                    }}
                                </button>
                            </span>
                        </fieldset>
                    </form>
                </template>
            </div>

            <!-- Item -->
            <div v-else class="item-panel page-section">
                <div class="mb-3 filters d-flex align-items-center gap-3">
                    <label class="checkbox-inline">
                        <input v-model="holdableOnly" type="checkbox" />
                        {{ $__("Show holdable items only") }}
                    </label>
                </div>

                <KohaTable
                    ref="itemsTable"
                    v-bind="itemsTableOptions"
                    @select-item="onSelectItem"
                />

                <template v-if="selectedItem">
                    <h3>
                        {{
                            $__("Selected item: %s").format(
                                selectedItem.external_id
                            )
                        }}
                    </h3>

                    <div v-if="itemHoldabilityLoading" class="placeholder-glow">
                        <p class="placeholder col-6"></p>
                    </div>

                    <template v-else-if="itemHoldabilityResult">
                        <div v-if="!itemAvailable" class="alert alert-danger">
                            <p class="mb-1">
                                {{ $__("This hold cannot be placed:") }}
                            </p>
                            <ul class="mb-2">
                                <li
                                    v-for="b in itemBlockedReasons"
                                    :key="b.code"
                                >
                                    {{ b.label }}
                                </li>
                            </ul>
                        </div>

                        <div v-if="itemErrorMessage" class="alert alert-danger">
                            {{ itemErrorMessage }}
                        </div>

                        <form @submit.prevent="handleItemSubmit">
                            <fieldset class="rows">
                                <ol>
                                    <li>
                                        <FormElement
                                            :resource="itemFormData"
                                            :attr="itemPickupLibraryField"
                                            :index="0"
                                        />
                                    </li>
                                    <li
                                        v-for="(attr, index) in extraHoldFields"
                                        :key="attr.name"
                                    >
                                        <FormElement
                                            :resource="itemFormData"
                                            :attr="attr"
                                            :index="index + 1"
                                        />
                                    </li>
                                </ol>
                            </fieldset>

                            <fieldset class="action">
                                <span
                                    class="submit-tooltip"
                                    :title="
                                        itemCanSubmit
                                            ? null
                                            : itemDisabledReason
                                    "
                                >
                                    <button
                                        type="submit"
                                        class="btn btn-primary"
                                        :disabled="
                                            itemHoldPlaced || !itemCanSubmit
                                        "
                                    >
                                        <span
                                            v-if="itemPlacing"
                                            class="spinner-border spinner-border-sm"
                                            aria-hidden="true"
                                        ></span>
                                        {{
                                            itemOverridable
                                                ? $__("Override and place hold")
                                                : $__("Place hold")
                                        }}
                                    </button>
                                </span>
                            </fieldset>
                        </form>
                    </template>
                </template>
            </div>
        </div>

        <Toast
            v-model="toastVisible"
            :title="$__('Hold placed')"
            :message="toastMessage"
        />
    </div>
</template>

<script>
import { computed, onMounted, reactive, ref, useTemplateRef, watch } from "vue";
import { storeToRefs } from "pinia";
import { APIClient } from "../../../fetch/api-client.js";
import { useHoldsStore } from "../../../stores/holds.js";
import { useHoldSubmission } from "../../../composables/hold-submission.js";
import { blockerLabel } from "../../../composables/hold-blocker-labels.js";
import FormElement from "../../FormElement.vue";
import Toast from "../../Elements/Toast.vue";
import KohaTable from "../../KohaTable.vue";
import HoldabilityShield from "./HoldabilityShield.vue";
import ExpressBibLevelHold from "./ExpressBibLevelHold.vue";
import { $__ } from "@koha-vue/i18n";

// One item-status label per (mutually exclusive, in this priority order)
// item field - a plain-language summary of what would otherwise be four
// separate raw flags. There's no single "status" field on the API item
// resource to filter this column by server-side, so unlike Barcode/Home
// library/Item type it isn't wired into add_filters below.
const itemStatusLabel = row => {
    if (row.checked_out_date) return $__("On loan");
    if (row.lost_status) return $__("Lost");
    if (row.damaged_status) return $__("Damaged");
    if (row.withdrawn) return $__("Withdrawn");
    if (row.not_for_loan_status) return $__("Not for loan");
    return $__("Available");
};

export default {
    name: "GranularItemHold",
    components: {
        ExpressBibLevelHold,
        FormElement,
        HoldabilityShield,
        KohaTable,
        Toast,
    },
    props: {
        biblio: { type: Object, required: true }, // { biblio_id, title }
        patron: { type: Object, required: true }, // { patron_id, library_id, library: { name } }
    },
    setup(props) {
        const holdsStore = useHoldsStore();
        const { sysprefs } = storeToRefs(holdsStore);

        // Fields common to the Item group and Item panels, beyond the
        // pickup library field each builds separately (the Item panel's
        // needs a dynamic preloadedOptions prop the other doesn't).
        const extraHoldFields = computed(() => [
            { name: "hold_date", type: "date", label: $__("Hold starts") },
            { name: "expiration_date", type: "date", label: $__("Expires") },
            {
                name: "notes",
                type: "textarea",
                label: $__("Notes"),
                textAreaRows: 3,
            },
        ]);

        const holdType = ref("item");

        /* ---------------------------------------------------------------
         * Item group panel
         * ----------------------------------------------------------- */
        const itemGroups = ref([]);
        const showItemGroupOption = computed(
            () =>
                sysprefs.value.EnableItemGroupHolds &&
                itemGroups.value.length > 0
        );

        onMounted(() => {
            if (!sysprefs.value.EnableItemGroupHolds) return;
            APIClient.item_group.list(props.biblio.biblio_id).then(
                result => (itemGroups.value = result || []),
                () => {} // No item groups (or the call failed) - the radio option just stays hidden.
            );
        });

        const selectedGroupId = ref(null);
        const groupFormData = reactive({
            pickup_library_id: props.patron.library_id,
            hold_date: null,
            expiration_date: null,
            notes: "",
        });

        const groupAvailable = ref(false);
        const groupOverridable = ref(false);
        const groupBlockedReasons = ref([]);
        const groupChecked = ref(false);
        const groupCanSubmit = computed(
            () => groupAvailable.value || groupOverridable.value
        );
        const groupDisabledReason = computed(() =>
            groupBlockedReasons.value.map(r => r.label).join("\n")
        );

        const handleGroupEligibility = () => {
            groupAvailable.value = true;
            groupOverridable.value = false;
            groupChecked.value = true;
        };
        const handleGroupBlocked = ({ blockers, overridable }) => {
            groupAvailable.value = false;
            groupOverridable.value = overridable;
            groupBlockedReasons.value = blockers;
            groupChecked.value = true;
        };

        const {
            placing: groupPlacing,
            holdPlaced: groupHoldPlaced,
            errorMessage: groupErrorMessage,
            submit: groupSubmit,
        } = useHoldSubmission();

        const pickupLibraryField = computed(() => ({
            name: "pickup_library_id",
            type: "component",
            label: $__("Pickup library"),
            required: true,
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

        const handleGroupSubmit = () => {
            const result = groupSubmit(
                groupAvailable.value,
                groupOverridable.value,
                groupBlockedReasons.value,
                {
                    patron_id: props.patron.patron_id,
                    item_group_id: selectedGroupId.value,
                    pickup_library_id: groupFormData.pickup_library_id,
                    hold_date: groupFormData.hold_date || undefined,
                    expiration_date: groupFormData.expiration_date || undefined,
                    notes: groupFormData.notes || undefined,
                }
            );
            if (result) result.then(onHoldPlaced).catch(() => {});
        };

        /* ---------------------------------------------------------------
         * Item panel
         * ----------------------------------------------------------- */
        const itemsTable = useTemplateRef("itemsTable");
        const holdableOnly = ref(false);
        const selectedItem = ref(null);
        const itemHoldabilityResult = ref(null);
        const itemHoldabilityLoading = ref(false);

        const getItemTableColumns = () => [
            {
                title: $__("Select"),
                data: "",
                name: "select",
                searchable: false,
                orderable: false,
                render: (data, type, row) => {
                    if (type !== "display") return "";
                    const holdability = row.holdability;
                    if (!holdability) return "";

                    const overridableRow =
                        holdability.blockers &&
                        holdability.blockers.every(b => b.overridable);
                    const canSelect =
                        holdability.available ||
                        (sysprefs.value.AllowHoldPolicyOverride &&
                            overridableRow);

                    const titleAttr = (holdability.blockers || [])
                        .map(b => blockerLabel(b.code))
                        .join("\n");

                    if (!canSelect) {
                        return `<span class="text-muted" title="${escape_str(titleAttr)}"><i class="fa fa-ban"></i></span>`;
                    }

                    const warningIcon = holdability.available
                        ? ""
                        : `<i class="fa fa-exclamation-circle text-warning" title="${escape_str(titleAttr)}"></i> `;
                    return `${warningIcon}<button type="button" class="select-item btn btn-xs btn-primary">${$__("Select")}</button>`;
                },
            },
            {
                title: $__("Barcode"),
                data: "external_id",
                searchable: true,
                orderable: true,
            },
            {
                title: $__("Home library"),
                data: "home_library_id",
                searchable: true,
                orderable: true,
            },
            {
                title: $__("Item type"),
                data: "item_type_id",
                searchable: true,
                orderable: true,
            },
            {
                title: $__("Status"),
                data: "",
                searchable: false,
                orderable: false,
                render: (data, type, row) => escape_str(itemStatusLabel(row)),
            },
        ];

        // patron_id/holdability are read by the controller as literal
        // top-level query params (and stripped before the generic
        // search/filter machinery runs) - they aren't real columns on the
        // items table, so they have to be baked into the URL itself rather
        // than passed through default_filters, which builds a DBIC `q`
        // JSON filter instead (same approach AgreementResource.vue's
        // tableUrl() uses for its own static query params).
        const itemsTableOptions = ref({
            columns: getItemTableColumns(),
            url: `/api/v1/biblios/${props.biblio.biblio_id}/items?patron_id=${props.patron.patron_id}&holdability=1`,
            options: {
                pageLength: 20,
                ordering: true,
                // DataTables defaults to ordering by column 0 when no
                // order is given - here that's the Select column, whose
                // data:'' reaches the backend as an empty order-by field
                // ("ORDER BY me." - Unknown column 'me'). Default to
                // Barcode (column 1, the first orderable column) instead.
                order: [[1, "asc"]],
            },
            add_filters: true,
            actions: { 0: ["select-item"] },
        });

        // Client-side, current-page-only: the API's holdability param
        // documents that only the requested page is checked, so
        // "holdable only" filters within that same page rather than asking
        // for a param the backend has no cheap way to answer (see the
        // Granular Hold plan notes on why this isn't a server-side filter).
        const applyHoldableOnlyFilter = () => {
            const dt = itemsTable.value && itemsTable.value.useTableObject();
            if (!dt) return;
            dt.rows().every(function () {
                const row = this.data();
                const show =
                    !holdableOnly.value ||
                    (row.holdability && row.holdability.available);
                $(this.node()).toggle(!!show);
            });
        };
        watch(holdableOnly, applyHoldableOnlyFilter);
        watch(itemsTable, table => {
            if (!table) return;
            const dt = table.useTableObject();
            if (!dt) return;
            dt.on("draw", applyHoldableOnlyFilter);
            applyHoldableOnlyFilter();
        });

        const itemFormData = reactive({
            pickup_library_id: null,
            hold_date: null,
            expiration_date: null,
            notes: "",
        });

        const onSelectItem = row => {
            selectedItem.value = row;
            itemHoldabilityResult.value = null;
            itemFormData.pickup_library_id = null;
            itemHoldabilityLoading.value = true;

            APIClient.circulation.holdability
                .item(row.item_id, {
                    patron_id: props.patron.patron_id,
                    include_pickup_locations: true,
                })
                .then(
                    result => {
                        itemHoldabilityResult.value = result;
                        itemHoldabilityLoading.value = false;
                    },
                    () => {
                        itemHoldabilityLoading.value = false;
                    }
                );
        };

        const itemAvailable = computed(
            () => !!itemHoldabilityResult.value?.available
        );
        const itemBlockedReasons = computed(() => {
            if (!itemHoldabilityResult.value || itemAvailable.value) return [];
            return itemHoldabilityResult.value.blockers.map(b => ({
                code: b.code,
                label: blockerLabel(b.code),
                overridable: b.overridable,
            }));
        });
        const itemOverridable = computed(() => {
            if (!itemHoldabilityResult.value || itemAvailable.value)
                return false;
            return (
                sysprefs.value.AllowHoldPolicyOverride &&
                itemHoldabilityResult.value.blockers.every(b => b.overridable)
            );
        });
        const itemCanSubmit = computed(
            () => itemAvailable.value || itemOverridable.value
        );
        const itemDisabledReason = computed(() =>
            itemBlockedReasons.value.map(r => r.label).join("\n")
        );

        const itemPickupLibraryField = computed(() => ({
            name: "pickup_library_id",
            type: "component",
            label: $__("Pickup library"),
            required: true,
            componentPath:
                "@koha-vue/components/Circulation/Holds/PickupLibrarySelect.vue",
            componentProps: {
                biblioId: { type: "string", value: props.biblio.biblio_id },
                patronId: { type: "string", value: props.patron.patron_id },
                preloadedOptions: {
                    type: "object",
                    value: itemHoldabilityResult.value?.pickup_locations || [],
                },
            },
        }));

        const {
            placing: itemPlacing,
            holdPlaced: itemHoldPlaced,
            errorMessage: itemErrorMessage,
            submit: itemSubmit,
        } = useHoldSubmission();

        const handleItemSubmit = () => {
            const result = itemSubmit(
                itemAvailable.value,
                itemOverridable.value,
                itemBlockedReasons.value,
                {
                    patron_id: props.patron.patron_id,
                    item_id: selectedItem.value.item_id,
                    pickup_library_id: itemFormData.pickup_library_id,
                    hold_date: itemFormData.hold_date || undefined,
                    expiration_date: itemFormData.expiration_date || undefined,
                    notes: itemFormData.notes || undefined,
                }
            );
            if (result) result.then(onHoldPlaced).catch(() => {});
        };

        /* ---------------------------------------------------------------
         * Shared success handling (toast + redirect), same as Express
         * ----------------------------------------------------------- */
        const toastVisible = ref(false);
        const toastMessage = ref("");
        const onHoldPlaced = hold => {
            if (!hold) return;
            toastMessage.value = $__("Queue position: #%s").format(
                hold.priority
            );
            toastVisible.value = true;
            setTimeout(() => {
                window.location = `/cgi-bin/koha/members/moremember.pl?borrowernumber=${props.patron.patron_id}#holds`;
            }, 1500);
        };

        return {
            holdType,
            showItemGroupOption,
            itemGroups,
            selectedGroupId,
            groupFormData,
            groupChecked,
            groupCanSubmit,
            groupDisabledReason,
            groupOverridable,
            groupPlacing,
            groupHoldPlaced,
            groupErrorMessage,
            handleGroupEligibility,
            handleGroupBlocked,
            handleGroupSubmit,
            pickupLibraryField,
            extraHoldFields,
            itemsTable,
            itemsTableOptions,
            holdableOnly,
            onSelectItem,
            selectedItem,
            itemHoldabilityResult,
            itemHoldabilityLoading,
            itemAvailable,
            itemBlockedReasons,
            itemOverridable,
            itemCanSubmit,
            itemDisabledReason,
            itemPickupLibraryField,
            itemFormData,
            itemPlacing,
            itemHoldPlaced,
            itemErrorMessage,
            handleItemSubmit,
            toastVisible,
            toastMessage,
        };
    },
};
</script>

<style scoped>
/* Plain radio switch, not a rows-style form fieldset (no <ol>/<li>) - the
   global fieldset.rows class floats left at 100% width, which left every
   panel after it (item-panel included) rendering alongside it instead of
   below, since none of those panels are themselves fieldset.rows to clear
   it. */
.hold-type {
    display: flex;
    align-items: center;
    flex-wrap: wrap;
    gap: 1rem;
    margin-bottom: 1rem;
}

.hold-type label {
    margin: 0;
    font-weight: normal;
}
</style>
