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
            <div class="page-section bg-info" v-if="ruleSetInitialized">
                <h2>{{ $__("Circulation context") }}</h2>
                <TriggerContext :ruleSetInfo="ruleSetInfo" />
            </div>
            <div v-else-if="editMode !== 'confirmContext'">
                <p>{{ $__("Loading rule set information...") }}</p>
            </div>
            <fieldset class="rows" v-if="contextInitialized">
                <legend>{{ $__("Confirm trigger context") }}</legend>
                <ol id="confirm-context-list">
                    <li>
                        <label for="library_id" class="required"
                            >{{ $__("Library") }}:</label
                        >
                        <v-select
                            id="library_id"
                            v-model="context.library_id"
                            label="name"
                            :reduce="lib => lib.library_id"
                            :options="libraries"
                            :disabled="editMode !== 'confirmContext'"
                        >
                            <template #search="{ attributes, events }">
                                <input
                                    :required="!context.library_id"
                                    class="vs__search"
                                    v-bind="attributes"
                                    v-on="events"
                                />
                            </template>
                        </v-select>
                        <span class="required">{{ $__("Required") }}</span>
                    </li>
                    <li>
                        <label for="patron_category_id" class="required"
                            >{{ $__("Patron category") }}:</label
                        >
                        <v-select
                            id="patron_category_id"
                            v-model="context.patron_category_id"
                            label="name"
                            :reduce="cat => cat.patron_category_id"
                            :options="patronCategories"
                            :disabled="editMode !== 'confirmContext'"
                        >
                            <template #search="{ attributes, events }">
                                <input
                                    :required="!context.patron_category_id"
                                    class="vs__search"
                                    v-bind="attributes"
                                    v-on="events"
                                />
                            </template>
                        </v-select>
                        <span class="required">{{ $__("Required") }}</span>
                    </li>
                    <li>
                        <label for="item_type_id" class="required"
                            >{{ $__("Item type") }}:</label
                        >
                        <v-select
                            id="item_type_id"
                            v-model="context.item_type_id"
                            label="description"
                            :reduce="type => type.item_type_id"
                            :options="itemTypes"
                            :disabled="editMode !== 'confirmContext'"
                        >
                            <template #search="{ attributes, events }">
                                <input
                                    :required="!context.item_type_id"
                                    class="vs__search"
                                    v-bind="attributes"
                                    v-on="events"
                                />
                            </template>
                        </v-select>
                        <span class="required">{{ $__("Required") }}</span>
                    </li>
                </ol>
                <div v-if="editMode === 'confirmContext'">
                    <router-link
                        :to="{
                            name: 'CirculationTriggersSelectOrAdd',
                            query: context,
                        }"
                        class="btn btn-default btn-xs float-end"
                        ><i class="fa-solid fa-pencil"></i>
                        {{ $__("Confirm context") }}</router-link
                    >
                </div>
                <div
                    class="page-section"
                    v-if="ruleSetInitialized && editMode !== 'confirmContext'"
                >
                    <TriggersTable
                        :triggerNumber="triggerNumber"
                        :modal="true"
                        :actions="true"
                        :ruleSets="effectiveTriggerFilteredRuleSets"
                        :ruleSetBeingEdited="currentRuleSet"
                        :triggerBeingEdited="triggerBeingEdited"
                    />
                </div>
            </fieldset>
            <div v-else>
                <p>{{ $__("Loading context...") }}</p>
            </div>
            <fieldset class="rows" v-if="alertMessage">
                <div class="alert alert-info">{{ alertMessage }}</div>
            </fieldset>
            <fieldset
                class="rows"
                v-if="
                    (ruleSetInitialized && editMode === 'edit') ||
                    editMode === 'add'
                "
                id="trigger-edit-form-general-section"
            >
                <legend v-if="editMode === 'add'">
                    {{ $__("Add new trigger") }}
                    {{ " " + triggerNumber }}
                </legend>
                <legend v-else>
                    {{ $__("Edit trigger") }} {{ " " + triggerNumber }}
                </legend>
                <div class="page-section bg-info">
                    <p>
                        {{
                            $__(
                                "NOTE: Delay for a given trigger can be pushed forward or backwards only within the bounds of what its two neighbouring triggers allows."
                            )
                        }}
                    </p>
                </div>
                <ol>
                    <li>
                        <label for="overdue_delay">{{ $__("Delay") }}: </label>
                        <div class="numeric-input-wrapper">
                            <div class="input-with-clear">
                                <input
                                    @input="setAllowSubmission"
                                    id="overdue_delay"
                                    v-model="
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_delay`
                                        ]
                                    "
                                    type="number"
                                    :placeholder="
                                        fallbackRuleSet?.[
                                            `overdue_${triggerNumber}_delay`
                                        ]
                                    "
                                    :min="minDelay"
                                    :max="maxDelay"
                                    class="numeric-input"
                                />
                                <button
                                    v-if="
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_delay`
                                        ] !== null &&
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_delay`
                                        ] !== undefined
                                    "
                                    type="button"
                                    class="clear-btn"
                                    @click="handleSetDelayToNull"
                                >
                                    <svg
                                        xmlns="http://www.w3.org/2000/svg"
                                        width="10"
                                        height="10"
                                    >
                                        <path
                                            d="M6.895455 5l2.842897-2.842898c.348864-.348863.348864-.914488 0-1.263636L9.106534.261648c-.348864-.348864-.914489-.348864-1.263636 0L5 3.104545 2.157102.261648c-.348863-.348864-.914488-.348864-1.263636 0L.261648.893466c-.348864.348864-.348864.914489 0 1.263636L3.104545 5 .261648 7.842898c-.348864.348863-.348864.914488 0 1.263636l.631818.631818c.348864.348864.914773.348864 1.263636 0L5 6.895455l2.842898 2.842897c.348863.348864.914772.348864 1.263636 0l.631818-.631818c.348864-.348864.348864-.914489 0-1.263636L6.895455 5z"
                                        ></path>
                                    </svg>
                                </button>
                                <div class="chevron-buttons">
                                    <button
                                        type="button"
                                        class="increment-btn"
                                        @click="incrementDelay"
                                    >
                                        ▴
                                    </button>
                                    <button
                                        type="button"
                                        class="decrement-btn"
                                        @click="decrementDelay"
                                    >
                                        ▾
                                    </button>
                                </div>
                            </div>
                        </div>
                    </li>
                    <li>
                        <label for="restricts"
                            >{{ $__("Restricts checkouts") }}:</label
                        >
                        <div>
                            <input
                                @click="setAllowSubmission"
                                type="radio"
                                id="restricts-yes"
                                v-model="
                                    ruleSetToSubmit[
                                        `overdue_${triggerNumber}_restrict`
                                    ]
                                "
                                :value="1"
                            />
                            {{ $__("Yes") }}
                            <input
                                @click="setAllowSubmission"
                                type="radio"
                                id="restricts-no"
                                v-model="
                                    ruleSetToSubmit[
                                        `overdue_${triggerNumber}_restrict`
                                    ]
                                "
                                :value="0"
                            />
                            {{ $__("No") }}
                            <input
                                @click="setAllowSubmission"
                                type="radio"
                                id="restricts-fallback"
                                v-model="
                                    ruleSetToSubmit[
                                        `overdue_${triggerNumber}_restrict`
                                    ]
                                "
                                :value="null"
                            />
                            {{ $__("Fallback to default") }}
                            <span
                                v-if="
                                    fallbackRuleSet?.[
                                        `overdue_${triggerNumber}_restrict`
                                    ] !== null
                                "
                            >
                                ({{
                                    fallbackRuleSet?.[
                                        `overdue_${triggerNumber}_restrict`
                                    ] === "1"
                                        ? $__("Yes")
                                        : $__("No")
                                }})
                            </span>
                        </div>
                    </li>
                </ol>
            </fieldset>
            <div v-else-if="editMode === 'add' || editMode === 'edit'">
                <p>{{ $__("Loading circulation rules...") }}</p>
            </div>
            <fieldset
                class="rows"
                v-if="
                    (ruleSetInitialized && editMode === 'edit') ||
                    editMode === 'add'
                "
                id="trigger-edit-form-notice-section"
            >
                <legend v-if="ruleSetInfo.triggerCount < triggerNumber">
                    {{ $__("Notice for trigger") }}
                    {{ " " + triggerNumber }}
                </legend>
                <legend v-else>
                    {{ $__("Edit notice for trigger") }}
                    {{ " " + triggerNumber }}
                </legend>
                <ol>
                    <li>
                        <label for="letter_code">{{ $__("Letter") }}:</label>
                        <v-select
                            id="letter_code"
                            v-model="
                                ruleSetToSubmit[
                                    `overdue_${triggerNumber}_notice`
                                ]
                            "
                            label="name"
                            :reduce="type => type.code"
                            :options="filteredLetters"
                            @update:modelValue="setAllowSubmission"
                        >
                            <template #search="{ attributes, events }">
                                <input
                                    class="vs__search"
                                    v-bind="attributes"
                                    v-on="events"
                                    :placeholder="
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_notice`
                                        ] === null ||
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_notice`
                                        ] === undefined
                                            ? letters.find(
                                                  letter =>
                                                      letter.code ===
                                                      fallbackRuleSet?.[
                                                          `overdue_${triggerNumber}_notice`
                                                      ]
                                              )?.name ||
                                              fallbackRuleSet?.[
                                                  `overdue_${triggerNumber}_notice`
                                              ]
                                            : ''
                                    "
                                />
                            </template>
                        </v-select>
                    </li>
                    <li
                        v-if="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_notice`
                            ] !== '' &&
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_notice`
                            ] !== null &&
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_notice`
                            ] !== undefined
                        "
                    >
                        <label for="mtt">{{ $__("Transport type(s)") }}:</label>
                        <v-select
                            id="mtt"
                            v-model="
                                ruleSetToSubmit[`overdue_${triggerNumber}_mtt`]
                            "
                            label="name"
                            :reduce="type => type.code"
                            :options="transportTypes"
                            multiple
                            :required="true"
                            @update:modelValue="setAllowSubmission"
                        >
                            <template #search="{ attributes, events }">
                                <input
                                    class="vs__search"
                                    v-bind="attributes"
                                    v-on="events"
                                    :placeholder="
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_mtt`
                                        ] === null ||
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_mtt`
                                        ] === undefined ||
                                        ruleSetToSubmit[
                                            `overdue_${triggerNumber}_mtt`
                                        ].length === 0
                                            ? fallbackRuleSet?.[
                                                  `overdue_${triggerNumber}_mtt`
                                              ]
                                            : ''
                                    "
                                    :required="
                                        !ruleSetToSubmit[
                                            `overdue_${triggerNumber}_mtt`
                                        ]?.length
                                    "
                                />
                            </template>
                        </v-select>
                    </li>
                </ol>
            </fieldset>
            <div v-else-if="editMode === 'add' || editMode === 'edit'">
                <p>{{ $__("Loading circulation rules...") }}</p>
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
import TriggerContext from "./TriggerContext.vue";
import { isEqual, cloneDeep } from "lodash";

export default {
    setup() {
        const circRulesStore = inject("circRulesStore");
        const {
            updateTriggerCount,
            findEffectiveRule,
            getSelectedRuleSet,
            setEffectiveTriggerFilteredRuleSet,
            updateCircRuleSets,
            hasConflict,
        } = circRulesStore;
        const {
            letters,
            libraries,
            itemTypes,
            transportTypes,
            patronCategories,
            triggerCounts,
            storeInitialized,
        } = storeToRefs(circRulesStore);

        return {
            letters,
            itemTypes,
            libraries,
            transportTypes,
            triggerCounts,
            patronCategories,
            getSelectedRuleSet,
            updateTriggerCount,
            findEffectiveRule,
            setEffectiveTriggerFilteredRuleSet,
            updateCircRuleSets,
            hasConflict,
            storeInitialized,
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
        // handle hard refresh mid-stepper workflow by ensuring store is initialized
        if (!this.storeInitialized) {
            this.$watch("storeInitialized", newVal => {
                if (newVal) {
                    this.initializeComponent();
                }
            });
            return;
        }
        this.initializeComponent();
    },
    beforeRouteEnter(to, from, next) {
        if (!from.name) {
            next();
            return;
        }
        next(vm => vm.initializeComponent());
    },
    methods: {
        initializeComponent() {
            const { query } = this.$route;
            this.setEditMode();
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

            // ensure that no property is set to null as this would delete the rule!
            if (
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] !==
                    null &&
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] !==
                    this.fallbackRuleSet[`overdue_${this.triggerNumber}_delay`]
            ) {
                ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] =
                    cloneDeep(
                        this.ruleSetToSubmit[
                            `overdue_${this.triggerNumber}_delay`
                        ]
                    );
            }

            if (
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_notice`] !==
                    null &&
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_notice`] !==
                    this.fallbackRuleSet[`overdue_${this.triggerNumber}_notice`]
            ) {
                ruleSetToSubmit[`overdue_${this.triggerNumber}_notice`] =
                    cloneDeep(
                        this.ruleSetToSubmit[
                            `overdue_${this.triggerNumber}_notice`
                        ]
                    );
            }

            if (
                this.ruleSetToSubmit[
                    `overdue_${this.triggerNumber}_restrict`
                ] !== null &&
                this.ruleSetToSubmit[
                    `overdue_${this.triggerNumber}_restrict`
                ] !==
                    this.fallbackRuleSet[
                        `overdue_${this.triggerNumber}_restrict`
                    ]
            ) {
                ruleSetToSubmit[`overdue_${this.triggerNumber}_restrict`] =
                    cloneDeep(
                        this.ruleSetToSubmit[
                            `overdue_${this.triggerNumber}_restrict`
                        ]
                    );
            }

            if (
                this.ruleSetToSubmit[`overdue_${this.triggerNumber}_mtt`] !==
                    null &&
                Array.isArray(
                    this.ruleSetToSubmit[`overdue_${this.triggerNumber}_mtt`]
                ) &&
                !isEqual(
                    this.ruleSetToSubmit[`overdue_${this.triggerNumber}_mtt`],
                    this.fallbackRuleSet[`overdue_${this.triggerNumber}_mtt`]
                )
            ) {
                ruleSetToSubmit[`overdue_${this.triggerNumber}_mtt`] =
                    cloneDeep(
                        this.ruleSetToSubmit[
                            `overdue_${this.triggerNumber}_mtt`
                        ].join(",")
                    );
            }

            ruleSetToSubmit[`overdue_${this.triggerNumber}_has_rules`] = true;

            // in edit mode, check for changes from elsewhere to the rule set being edited
            if (this.editMode === "edit") {
                const ruleSetInDb = await this.getSelectedRuleSet(this.context);
                if (
                    this.hasConflict(
                        ruleSetInDb,
                        this.currentRuleSet,
                        this.triggerNumber
                    )
                ) {
                    this.alertMessage =
                        "Your changes could not be saved as this circulation trigger was updated elsewhere. Please see the updated trigger below.";
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
                    [`overdue_${this.triggerNumber}_restrict`]: null,
                };
            }
            this.setMaxDelay();
            this.setRuleSetInfo();
            this.effectiveTriggerFilteredRuleSets =
                this.setEffectiveTriggerFilteredRuleSet(this.context);
            this.setFallbackRuleSet();
            this.setFilteredLetters();
            this.setAllowSubmission();
            this.ruleSetInitialized = true;
        },
        setContext(query) {
            this.context.library_id = query.library_id ?? "*";
            this.context.item_type_id = query.item_type_id ?? "*";
            this.context.patron_category_id = query.patron_category_id ?? "*";
        },
        setEditMode() {
            this.editMode = this.$route.path.substring(
                this.$route.path.lastIndexOf("/") + 1
            );
        },
        setRuleSetInfo() {
            this.ruleSetInfo = {
                issuelength: this.currentRuleSet.issuelength,
                decreaseloanholds: this.currentRuleSet.decreaseloanholds,
                fine: this.currentRuleSet.fine,
                chargeperiod: this.currentRuleSet.chargeperiod,
                lengthunit: this.currentRuleSet.lengthunit,
                triggerCount: this.triggerCounts[this.context.library_id],
            };
        },
        async setCurrentRuleSet() {
            this.currentRuleSet = await this.getSelectedRuleSet(
                this.context,
                true
            );
            // override the context as fetched from the DBto ensure it matches the selected context
            // FIXME: consider passing the context to trigger table separately
            this.currentRuleSet.context = this.context;
        },
        setTriggerNumber(triggerNumber, library_id) {
            this.triggerNumber =
                this.editMode === "edit"
                    ? triggerNumber
                    : this.triggerCounts[library_id] + 1;
        },
        setFallbackRuleSet() {
            this.fallbackRuleSet = {
                [`overdue_${this.triggerNumber}_delay`]: this.findEffectiveRule(
                    this.context,
                    "delay",
                    i
                ).value,
            };

            if (this.editMode === "add") {
                return;
            }
            this.fallbackRuleSet = {
                [`overdue_${this.triggerNumber}_delay`]: this.findEffectiveRule(
                    this.context,
                    "delay",
                    this.triggerNumber
                ).value,
                [`overdue_${this.triggerNumber}_notice`]:
                    this.findEffectiveRule(
                        this.context,
                        "notice",
                        this.triggerNumber
                    ).value,
                [`overdue_${this.triggerNumber}_mtt`]: this.findEffectiveRule(
                    this.context,
                    "mtt",
                    this.triggerNumber
                ).value,
                [`overdue_${this.triggerNumber}_restrict`]:
                    this.findEffectiveRule(
                        this.context,
                        "restrict",
                        this.triggerNumber
                    ).value,
            };
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
            const library = this.currentRuleSet.library_id;
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
            // if notice is set to "", this translates to 'No letter', for which submisison is allowed, and mtt is redundant
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
            const noticeAllowSubmisison =
                this.ruleSetToSubmit?.[
                    `overdue_${this.triggerNumber}_notice`
                ] != null;
            const mttHasItems =
                this.ruleSetToSubmit?.[`overdue_${this.triggerNumber}_mtt`]
                    ?.length;
            if (noticeAllowSubmisison && mttHasItems) {
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
        handleSetDelayToNull() {
            this.ruleSetToSubmit[`overdue_${this.triggerNumber}_delay`] = null;
            this.setAllowSubmission();
        },
        async scrollToTriggerEditForm() {
            let count = 0;
            // ensures that the relevant section is loaded before we attempt to scroll it into view
            while (
                !document.getElementById("trigger-edit-form-general-section") &&
                count < 8
            ) {
                await new Promise(resolve => setTimeout(resolve, 250));
                count++;
            }
            document
                .getElementById("trigger-edit-form-general-section")
                .scrollIntoView({ behavior: "smooth" });
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
                    newVal.query.triggerNumber !== oldVal.query.triggerNumber
                ) {
                    this.$router.go(0);
                }
            },
        },
        async editMode(newValue) {
            if (newValue === "add" || newValue === "edit") {
                await this.$nextTick();
                await this.scrollToTriggerEditForm();
            }
        },
    },
    components: { TriggersTable, ButtonSubmit, TriggerContext },
};
</script>

<style scoped>
#circulation-trigger-form-add {
    max-height: 90vh;
}

form li {
    display: flex;
    align-items: center;
}

.numeric-input-wrapper {
    position: relative;
    display: inline-block;
    width: 30%;
}

.input-with-clear {
    position: relative;
    display: flex;
    align-items: center;
    width: 100%;
}

.numeric-input {
    padding-right: 40px; /* Adjust to leave space for clear button */
    padding-left: 0.25em;
    padding-top: 2px;
    padding-bottom: 2px;
    width: 100%;
    border-radius: 4px;
    border: 1px solid #ccc;
    font-size: 16px;
    box-sizing: border-box;
    transition: border-color 0.2s ease;
}

.clear-btn {
    position: absolute;
    right: 22px; /* Adjust positioning */
    fill: var(--vs-controls-color);
    background-color: transparent;
    border: 0;
    font-size: 1.2em;
    color: #333;
    cursor: pointer;
    z-index: 2; /* Ensure it is above the input */
}

.button:active:hover,
.clear-btn:active:hover {
    background-color: #d4d4d4;
    border-color: #8c8c8c;
}

/* Chevron buttons container */
.chevron-buttons {
    display: flex;
    flex-direction: column;
    position: absolute;
    right: 0px;
    top: 0;
    bottom: 0;
    width: 16px;
    padding: 0px 5px 0px 2px;
    justify-content: center;
    z-index: 2;
}

/* Chevron button styles */
.increment-btn,
.decrement-btn {
    background-color: transparent;
    border: 0px solid #ccc;
    font-size: 10px;
    padding: 0px;
    cursor: pointer;
    color: rgba(60, 60, 60, 0.5);
    border-radius: 2px;
}

.increment-btn:hover,
.decrement-btn:hover {
    background-color: #ddd;
}

/* Hide the native increment/decrement buttons */
input[type="number"]::-webkit-inner-spin-button,
input[type="number"]::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
}

input[type="number"] {
    -moz-appearance: textfield; /* For Firefox */
}

.numeric-input:focus,
.numeric-input:hover {
    border-color: #007bff; /* Match focus color of v-select */
    outline: none;
}

.dialog.alert
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(
        .bg-success
    ):not(.bg-primary):not(.action),
.dialog.error
    fieldset:not(.bg-danger):not(.bg-warning):not(.bg-info):not(
        .bg-success
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

#confirm-context-list {
    display: flex;
    gap: 20px;
    height: fit-content;
}

#confirm-context-list li {
    display: flex;
    flex-direction: column;
    width: 320px;
}

#confirm-context-list .v-select {
    width: 100%;
}

#confirm-context-list label {
    width: 100%;
    text-align: left;
    padding: 0 0 4px 10px;
}

#confirm-context-list span {
    width: 100%;
    align-content: right;
    padding-top: 4px;
}

#confirm-context-list :deep(.v-select ul) {
    max-height: 120px;
}
</style>
