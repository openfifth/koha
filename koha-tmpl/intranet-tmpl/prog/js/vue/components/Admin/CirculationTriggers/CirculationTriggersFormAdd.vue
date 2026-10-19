<template>
    <form
        class="modal-content"
        id="circulation-trigger-form-add"
        @submit="addCircRule($event)"
    >
        <div class="modal-header">
            <h1 class="modal-title">
                {{ $__("Circulation Trigger Configuration") }}
            </h1>
            <router-link
                class="btn-close"
                type="button"
                :to="{
                    name: 'CirculationTriggersList',
                }"
            ></router-link>
        </div>
        <div class="modal-body">
            <div class="page-section">
                <fieldset class="rows" v-if="alertMessage">
                    <div class="alert alert-warning">{{ alertMessage }}</div>
                </fieldset>
            </div>
            <div
                :class="{
                    'bg-success-subtle': editMode !== 'confirmContext',
                    'page-section': true,
                }"
            >
                <ConfirmContext
                    :context="context"
                    :contextInitialized="contextInitialized"
                    :editMode="editMode"
                    :canManageAnyLibrary="canManageAnyLibrary"
                    :libraries="libraries"
                    :user_library_id="user_library_id"
                    :patronCategories="patronCategories"
                    :itemTypes="itemTypes"
                />
            </div>
            <div class="page-section" v-if="ruleSetInitialized">
                <CirculationRulesSummary :ruleSetInfo="ruleSetInfo" />
            </div>
            <div v-else-if="editMode !== 'confirmContext'">
                <p>{{ $__("Loading rule set information...") }}</p>
            </div>
            <div
                :class="{
                    'bg-success-subtle': editMode !== 'selectOrAdd',
                    'page-section': true,
                }"
                v-if="ruleSetInitialized && editMode !== 'confirmContext'"
            >
                <TriggersTable
                    :triggerNumber="triggerNumber"
                    :modal="true"
                    :displayActions="true"
                    :enableActions="editMode === 'selectOrAdd'"
                    :ruleSets="effectiveTriggerFilteredRuleSets"
                    :ruleSetBeingEdited="currentRuleSet"
                    :triggerBeingEdited="triggerBeingEdited"
                />
            </div>
            <div
                class="page-section"
                v-if="editMode === 'add' || editMode === 'edit'"
            >
                <EditActions
                    :ruleSetInitialized="ruleSetInitialized"
                    :editMode="editMode"
                    :triggerNumber="triggerNumber"
                    :ruleSetToSubmit="ruleSetToSubmit"
                    :fallbackRuleSet="fallbackRuleSet"
                    :minDelay="minDelay"
                    :maxDelay="maxDelay"
                    :setAllowSubmission="setAllowSubmission"
                    :incrementDelay="incrementDelay"
                    :decrementDelay="decrementDelay"
                    :handleLost="handleLost"
                    :lostValues="lostValues"
                />
            </div>
            <div
                class="page-section"
                v-if="editMode === 'add' || editMode === 'edit'"
            >
                <EditNotice
                    :ruleSetInitialized="ruleSetInitialized"
                    :editMode="editMode"
                    :triggerNumber="triggerNumber"
                    :ruleSetToSubmit="ruleSetToSubmit"
                    :fallbackRuleSet="fallbackRuleSet"
                    :ruleSetInfo="ruleSetInfo"
                    :filteredLetters="filteredLetters"
                    :handleNoticeChange="handleNoticeChange"
                    :letters="letters"
                    :transportTypes="transportTypes"
                    :setAllowSubmission="setAllowSubmission"
                />
            </div>
        </div>
        <div class="modal-footer">
            <ButtonSubmit
                v-if="editMode === 'edit' || editMode === 'add'"
                :disabled="!allowSubmission"
            />
            <router-link
                :to="{
                    name: 'CirculationTriggersList',
                }"
                >{{ $__("Cancel") }}</router-link
            >
        </div>
    </form>
</template>

<script>
import TriggersTable from "./TriggersTable.vue";
import { inject } from "vue";
import { storeToRefs } from "pinia";
import ButtonSubmit from "../../ButtonSubmit.vue";
import CirculationRulesSummary from "./CirculationRulesSummary.vue";
import ConfirmContext from "./ConfirmContext.vue";
import EditActions from "./EditActions.vue";
import EditNotice from "./EditNotice.vue";
import { isEqual, cloneDeep } from "lodash";
import {
    buildProjectedRuleSet,
    containsMatchingContext,
    ruleSuffixes,
    handleLost,
    hasConflict,
    scrollToElementById,
    setEffectiveTriggerFilteredRuleSet,
} from "@koha-vue/composables/circulation-rules";

export default {
    setup() {
        const circRulesStore = inject("circRulesStore");
        const { updateTriggerCount, getSelectedRuleSet, updateCircRuleSets } =
            circRulesStore;
        const {
            letters,
            lostValues,
            libraries,
            itemTypes,
            transportTypes,
            patronCategories,
            triggerCounts,
            currentLibraryId,
            currentAndDefaultRawRuleSets,
            lastEditedTriggerNumber,
            canManageAnyLibrary,
            user_library_id,
        } = storeToRefs(circRulesStore);

        return {
            letters,
            itemTypes,
            libraries,
            lostValues,
            transportTypes,
            triggerCounts,
            currentLibraryId,
            currentAndDefaultRawRuleSets,
            patronCategories,
            getSelectedRuleSet,
            updateTriggerCount,
            updateCircRuleSets,
            lastEditedTriggerNumber,
            canManageAnyLibrary,
            user_library_id,
            handleLost,
        };
    },
    data() {
        return {
            triggerNumber: 1,
            context: {
                library_id: "*",
                item_type_id: "*",
                patron_category_id: "*",
            },
            fallbackRuleSet: null,
            ruleSetInfo: {
                issuelength: null,
                decreaseloanholds: null,
                fine: null,
                chargeperiod: null,
                lengthunit: null,
                triggerCount: null,
            },
            editMode: false,
            ruleSetToSubmit: null,
            currentRuleSet: null,
            triggerBeingEdited: null,
            minDelay: 0,
            maxDelay: Infinity,
            filteredLetters: [],
            alertMessage: null,
            allowSubmission: false,
            effectiveTriggerFilteredRuleSets: [],
            contextInitialized: false,
            ruleSetInitialized: false,
        };
    },
    beforeMount() {
        this.initializeComponent();
    },
    beforeRouteEnter(to, from, next) {
        if (!from.name) {
            next();
            return;
        }
        next(vm => vm.initializeComponent(to));
    },
    beforeRouteUpdate(to, from, next) {
        next();
        this.initializeComponent(to);
    },
    methods: {
        initializeComponent(route) {
            const { query } = route ?? this.$route;
            this.setEditMode(route);
            this.setContext(query);
            this.contextInitialized = true;
            this.setTriggerNumber(query.triggerNumber, this.context.library_id);
            if (
                ["selectOrAdd", "add", "edit"].some(str =>
                    this.$route.fullPath.includes(str)
                )
            ) {
                this.setRuleSets();
            }
        },
        async addCircRule(e) {
            e.preventDefault();

            const ruleSetToSubmit = {
                context: this.context,
            };

            const ownRuleSet = this.currentAndDefaultRawRuleSets.find(ruleSet =>
                containsMatchingContext([this.context], ruleSet.context)
            );

            for (const suffix of ruleSuffixes) {
                const field = `overdue_${this.triggerNumber}_${suffix}`;
                const value = this.ruleSetToSubmit[field];
                const fallback = this.fallbackRuleSet[field]?.value;

                const isMtt = suffix === "mtt";
                if (isMtt && value !== null && !Array.isArray(value)) {
                    continue;
                }

                const isSet = value !== null && value !== undefined;
                const overrides =
                    isSet &&
                    (isMtt ? !isEqual(value, fallback) : value !== fallback);

                if (overrides) {
                    ruleSetToSubmit[field] = isMtt
                        ? value.join(",")
                        : cloneDeep(value);
                    continue;
                }

                // Null deletes the stored rule; omitting the field leaves it in place.
                if (ownRuleSet?.[field] != null) {
                    ruleSetToSubmit[field] = null;
                }
            }

            // in edit mode, check for changes from elsewhere to the rule set being edited
            if (this.editMode === "edit") {
                const ruleSetInDb = await this.getSelectedRuleSet(
                    this.context,
                    true
                );
                // effective=true returns context as */*/* (fallback); override to match
                // the queried context, consistent with setCurrentRuleSet
                if (ruleSetInDb) {
                    ruleSetInDb.context = { ...this.context };
                }
                if (
                    hasConflict(
                        this.currentRuleSet,
                        ruleSetInDb,
                        this.triggerNumber
                    )
                ) {
                    this.alertMessage = this.$__(
                        "Your changes could not be saved as this circulation trigger was updated elsewhere. Please see the updated trigger below."
                    );
                    this.$router.push({
                        path: "/cgi-bin/koha/admin/circulation_triggers/edit",
                        query: {
                            library_id: this.context.library_id,
                            patron_category_id: this.context.patron_category_id,
                            item_type_id: this.context.item_type_id,
                            triggerNumber: this.triggerNumber,
                        },
                    });
                    return;
                }
            }

            await this.updateCircRuleSets(ruleSetToSubmit, this.triggerNumber);
            this.lastEditedTriggerNumber = this.triggerNumber;
            await this.$router.push({
                name: "CirculationTriggersList",
                query: { refresh: Date.now() },
            });
        },
        async setRuleSets() {
            this.updateTriggerCount();
            await this.setCurrentRuleSet();

            this.ruleSetToSubmit = cloneDeep(this.currentRuleSet);

            this.setMinDelay();
            if (this.ruleSetToSubmit === null) {
                this.ruleSetToSubmit = {
                    context: this.context,
                    [`overdue_${this.triggerNumber}_delay`]: `${this.minDelay}`,
                    [`overdue_${this.triggerNumber}_notice`]: null,
                    [`overdue_${this.triggerNumber}_mtt`]: null,
                    [`overdue_${this.triggerNumber}_lost`]: null,
                    [`overdue_${this.triggerNumber}_charge`]: null,
                    [`overdue_${this.triggerNumber}_mark_returned`]: null,
                    [`overdue_${this.triggerNumber}_forgive_fine`]: null,
                    [`overdue_${this.triggerNumber}_restrict`]: null,
                };
            }
            this.setMaxDelay();
            this.setRuleSetInfo();
            this.effectiveTriggerFilteredRuleSets =
                setEffectiveTriggerFilteredRuleSet(
                    this.currentAndDefaultRawRuleSets,
                    this.context,
                    this.triggerCounts[this.currentLibraryId]
                );
            this.setFallbackRuleSet();
            this.setFilteredLetters();
            this.setAllowSubmission();
            this.ruleSetInitialized = true;
        },
        setContext(query) {
            if (!this.canManageAnyLibrary && this.user_library_id) {
                this.context.library_id = this.user_library_id;
            } else {
                this.context.library_id = query.library_id ?? "*";
            }
            this.context.item_type_id = query.item_type_id ?? "*";
            this.context.patron_category_id = query.patron_category_id ?? "*";
        },
        setEditMode(route) {
            const resolvedRoute = route ?? this.$route;
            this.editMode = resolvedRoute.path.substring(
                resolvedRoute.path.lastIndexOf("/") + 1
            );
        },
        setRuleSetInfo() {
            this.ruleSetInfo = {
                issuelength: this.currentRuleSet.issuelength,
                decreaseloanholds: this.currentRuleSet.decreaseloanholds,
                fine: this.currentRuleSet.fine,
                chargeperiod: this.currentRuleSet.chargeperiod,
                lengthunit: this.currentRuleSet.lengthunit,
                renewalsallowed: this.currentRuleSet.renewalsallowed,
                auto_renew: this.currentRuleSet.auto_renew,
                triggerCount: this.triggerCounts[this.context.library_id],
            };
        },
        async setCurrentRuleSet() {
            this.currentRuleSet = await this.getSelectedRuleSet(
                this.context,
                true
            );
            if (this.currentRuleSet) {
                this.currentRuleSet.context = this.context;
            }
        },
        setTriggerNumber(triggerNumber, library_id) {
            this.triggerNumber =
                this.editMode === "edit"
                    ? parseInt(triggerNumber)
                    : (this.triggerCounts[library_id] ?? 0) + 1;
            this.triggerBeingEdited =
                this.editMode === "edit" ? parseInt(triggerNumber) : null;
        },
        setFallbackRuleSet() {
            this.fallbackRuleSet = buildProjectedRuleSet(
                { context: this.context },
                this.triggerNumber,
                this.currentAndDefaultRawRuleSets.filter(
                    ruleSet =>
                        !containsMatchingContext(
                            [this.context],
                            ruleSet.context
                        )
                )
            );
        },
        setMinDelay() {
            if (
                this.ruleSetToSubmit === null ||
                this.triggerNumber === 0 ||
                this.triggerNumber === 1
            ) {
                this.minDelay = 0;
                return;
            }
            const priorTriggerNumber = this.triggerNumber - 1;
            this.minDelay = this.currentRuleSet[
                `overdue_${priorTriggerNumber}_delay`
            ]
                ? parseInt(
                      this.currentRuleSet[`overdue_${priorTriggerNumber}_delay`]
                  ) + 1
                : 0;
        },
        setMaxDelay() {
            const nextTriggerNumber = parseInt(this.triggerNumber) + 1;
            this.maxDelay = this.currentRuleSet?.[
                `overdue_${nextTriggerNumber}_delay`
            ]
                ? parseInt(
                      this.currentRuleSet[`overdue_${nextTriggerNumber}_delay`]
                  ) - 1
                : Infinity;
        },
        setFilteredLetters() {
            const library = this.context.library_id;
            const byCode = new Map();

            for (const letter of this.letters) {
                if (letter.branchcode === library) {
                    byCode.set(letter.code, letter); // override
                } else if (
                    letter.branchcode === "" &&
                    !byCode.has(letter.code)
                ) {
                    byCode.set(letter.code, letter);
                }
            }

            this.filteredLetters = [...byCode.values()];
        },
        incrementDelay() {
            // Check for minDelay and maxDelay
            const min = this.minDelay !== undefined ? this.minDelay : 1;
            const max = this.maxDelay !== undefined ? this.maxDelay : Infinity;

            // Set to minDelay if it's null or undefined
            if (
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] ===
                    undefined ||
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] ===
                    null
            ) {
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] =
                    `${min}`;
            }

            // Increment within the valid range
            else {
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] =
                    Math.min(
                        parseInt(
                            this.ruleSetToSubmit[
                                `overdue_${this.triggerNumber}_delay`
                            ]
                        ) + 1,
                        max
                    );
            }
            this.setAllowSubmission();
        },
        decrementDelay() {
            // Check for minDelay
            const min = this.minDelay !== undefined ? this.minDelay : 1;
            let delay = parseInt(
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`]
            );
            // Decrement only if greater than minDelay
            if (delay > min) {
                delay--;
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] =
                    `${delay}`;
            }
            this.setAllowSubmission();
        },
        setAllowSubmission() {
            // the number input yields "" when cleared from the keyboard and null when
            // cleared with the button; a trigger with no delay is never processed
            const delay =
                this.ruleSetToSubmit?.[`overdue_${this.triggerNumber}_delay`];
            if (delay === "" || delay == null) {
                this.allowSubmission = false;
                return;
            }

            // if notice is set to "", this translates to 'No letter', for which submission is allowed, and mtt is redundant
            const noticeAllowSubmissionAndBypassMtt =
                this.ruleSetToSubmit?.[
                    `overdue_${this.triggerNumber}_notice`
                ] === "";
            if (noticeAllowSubmissionAndBypassMtt) {
                this.allowSubmission = true;
                return;
            }

            // check specificity required as 0 is a value that submission must be allowed for
            const delayAllowsSubmission =
                this.ruleSetToSubmit?.[`overdue_${this.triggerNumber}_delay`] !=
                null;
            if (delayAllowsSubmission) {
                this.allowSubmission = true;
                return;
            }

            // if notice is set, then ensure at least one transport has been set
            const noticeAllowsSubmisison =
                this.ruleSetToSubmit?.[
                    `overdue_${this.triggerNumber}_notice`
                ] != null;
            const mttHasItems =
                this.ruleSetToSubmit?.[`overdue_${this.triggerNumber}_mtt`]
                    ?.length;
            if (noticeAllowsSubmisison && mttHasItems) {
                this.allowSubmission = true;
                return;
            }

            const lostValueHasItems =
                this.ruleSetToSubmit?.[`overdue_${this.triggerNumber}_lost`] !=
                null;
            if (lostValueHasItems) {
                this.allowSubmission = true;
                return;
            }

            const chargeAllowsSubmission =
                this.ruleSetToSubmit?.[
                    `overdue_${this.triggerNumber}_charge`
                ] != null;
            if (chargeAllowsSubmission) {
                this.allowSubmission = true;
                return;
            }

            const markReturnedAllowsSubmission =
                this.ruleSetToSubmit?.[
                    `overdue_${this.triggerNumber}_mark_returned`
                ] != null;
            if (markReturnedAllowsSubmission) {
                this.allowSubmission = true;
                return;
            }

            const forgiveFineAllowsSubmission =
                this.ruleSetToSubmit?.[
                    `overdue_${this.triggerNumber}_forgive_fine`
                ] != null;
            if (forgiveFineAllowsSubmission) {
                this.allowSubmission = true;
                return;
            }

            const restrictAllowsSubmission =
                this.ruleSetToSubmit?.[
                    `overdue_${this.triggerNumber}_restrict`
                ] != null;
            if (restrictAllowsSubmission) {
                this.allowSubmission = true;
                return;
            }
            this.allowSubmission = false;
        },
        handleNoticeChange() {
            // "No letter" set on this context overrides the transports to
            // none as well.
            if (
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_notice`] ===
                ""
            ) {
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_mtt`] = [];
            }
            this.setAllowSubmission();
        },
    },
    watch: {
        $route: {
            immediate: true,
            handler: function (newVal, oldVal) {
                if (
                    oldVal &&
                    !oldVal.fullPath.includes("add") &&
                    !oldVal.fullPath.includes("edit") &&
                    oldVal.query.triggerNumber &&
                    newVal.query.triggerNumber != oldVal.query.triggerNumber
                ) {
                    this.$router.go(0);
                }
            },
        },
        async editMode(newValue) {
            if (newValue === "add" || newValue === "edit") {
                await this.$nextTick();
                await scrollToElementById("trigger-table-form");
            }
        },
    },
    components: {
        TriggersTable,
        ButtonSubmit,
        CirculationRulesSummary,
        ConfirmContext,
        EditActions,
        EditNotice,
    },
};
</script>

<style scoped>
#circulation-trigger-form-add {
    max-height: 90vh;
}

.dialog.alert
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(
        .bg-success-subtle
    ):not(.bg-primary):not(.action),
.dialog.error
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(
        .bg-success-subtle
    ):not(.bg-primary):not(.action) {
    margin: 0;
    background-color: rgba(255, 255, 255, 1);
}

.router-link-active {
    margin-left: 10px;
}
.modal-header {
    display: flex;
    justify-content: space-between;
}

.modal-body {
    min-height: 280px;
}

#circulation-trigger-form-add .page-section {
    display: flow-root;
}
</style>
