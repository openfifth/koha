<template>
    <Toolbar>
        <ToolbarButton
            :to="{
                name: 'CirculationTriggersFormConfirmContext',
                query: {
                    library_id: currentLibraryId,
                    patron_category_id: currentPatronCategoryId,
                    item_type_id: currentItemTypeId,
                },
            }"
            icon="plus"
            :title="$__('Add new trigger')"
        />
    </Toolbar>
    <div v-if="filtersInitialized">
        <h1>{{ $__("Circulation triggers") }}</h1>
        <div class="page-section bg-info">
            <p>
                {{
                    $__(
                        "Rules are applied from most specific to less specific, using the first found in this order"
                    )
                }}:
            </p>
            <ul>
                <li>
                    {{
                        $__(
                            "same library, same patron category, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "same library, same patron category, all item types"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "same library, all patron categories, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "same library, all patron categories, all item types"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), same patron category, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), same patron category, all item types"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), all patron categories, same item type"
                        )
                    }}
                </li>
                <li>
                    {{
                        $__(
                            "default (all libraries), all patron categories, all item types"
                        )
                    }}
                </li>
            </ul>
            <p>
                {{
                    $__(
                        "The system is currently set to match based on the %s"
                    ).format(from_branch)
                }}
            </p>
        </div>
        <div class="page-section" v-if="filtersInitialized">
            <legend>
                Filter by
                <span style="color: blue; font-weight: bold">context</span>
            </legend>
            <table>
                <thead>
                    <tr>
                        <th>{{ $__("Library") }}</th>
                        <th>{{ $__("Category") }}</th>
                        <th>{{ $__("Item type") }}</th>
                    </tr>
                </thead>
                <tbody>
                    <tr>
                        <td>
                            <v-select
                                id="library_select"
                                v-model="currentLibraryId"
                                label="name"
                                :reduce="lib => lib.library_id"
                                :options="libraries"
                                @update:modelValue="
                                    filterRuleSetsbySearchParam()
                                "
                                :clearable="false"
                                placeholder="Default rules for all libraries"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!currentLibraryId"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </td>
                        <td>
                            <v-select
                                id="patron_category_select"
                                v-model="currentPatronCategoryId"
                                label="name"
                                :reduce="cat => cat.patron_category_id"
                                :options="patronCategories"
                                @update:modelValue="
                                    filterRuleSetsbySearchParam()
                                "
                                placeholder="any"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!currentPatronCategoryId"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </td>
                        <td>
                            <v-select
                                id="item_type_select"
                                v-model="currentItemTypeId"
                                label="description"
                                :reduce="itype => itype.item_type_id"
                                :options="itemTypes"
                                @update:modelValue="
                                    filterRuleSetsbySearchParam()
                                "
                                placeholder="any"
                            >
                                <template #search="{ attributes, events }">
                                    <input
                                        :required="!currentItemTypeId"
                                        class="vs__search"
                                        v-bind="attributes"
                                        v-on="events"
                                    />
                                </template>
                            </v-select>
                        </td>
                    </tr>
                </tbody>
            </table>
            <div class="toggle-view-all-applicable-wrapper">
                <label for="filter-rules">{{ $__("Display ") }}</label>
                <v-select
                    id="filter-rules"
                    v-model="displayAllApplicableRules"
                    :reduce="opt => opt.value"
                    :options="[
                        {
                            value: 0,
                            label: 'explictly set rules.',
                        },
                        {
                            value: 1,
                            label: 'all applied rules.',
                        },
                    ]"
                    @update:modelValue="filterRuleSetsbySearchParam()"
                >
                </v-select>
            </div>
        </div>
    </div>
    <div v-if="filtersInitialized && ruleSetInitialized">
        <div id="circ_triggers_tabs" class="toptabs numbered">
            <ul class="nav nav-tabs" role="tablist">
                <li
                    v-for="number in triggerCounts[currentLibraryId]"
                    class="nav-item"
                    role="presentation"
                    :key="`noticeTab_${number}`"
                >
                    <a
                        href="#"
                        class="nav-link"
                        role="tab"
                        v-bind:class="
                            tabSelected === `Notice ${number}` ? 'active' : ''
                        "
                        @click="changeTabContent"
                        :data-content="`Notice ${number}`"
                        >{{ $__("Trigger") + " " + number }}
                    </a>
                </li>
            </ul>
        </div>
        <div class="tab-content">
            <template v-for="number in triggerCounts[currentLibraryId]">
                <div
                    class="tab-pane"
                    role="tabpanel"
                    v-bind:class="
                        tabSelected === `Notice ${number}` ? 'show active' : ''
                    "
                    v-if="tabSelected === `Notice ${number}`"
                    :key="`noticeTabContent_${number}`"
                >
                    <div class="page-section">
                        <TriggersTable
                            :modal="false"
                            :actions="true"
                            :ruleSets="ruleSets"
                            :triggerNumber="number"
                        >
                            <router-link
                                v-if="isLastTrigger(number)"
                                :to="{
                                    name: 'CirculationTriggersFormConfirmTriggerDelete',
                                    query: {
                                        triggerNumber: number,
                                    },
                                }"
                                class="btn btn-primary"
                            >
                                <i class="fa-solid fa-xmark"></i>
                                {{ $__("Delete") }}
                            </router-link>
                            <div
                                :class="{
                                    'page-section bg-info': true,
                                    'inline-block': isLastTrigger(number),
                                }"
                            >
                                {{
                                    $__(
                                        "Bolid italic values denote fallback values where an override has not been set for the context."
                                    )
                                }}
                            </div>
                        </TriggersTable>
                    </div>
                </div>
            </template>
        </div>
    </div>
    <div v-if="showModal" class="modal" role="dialog">
        <div
            class="modal-dialog modal-dialog-centered modal-lg modal-dialog-scrollable"
            role="document"
        >
            <router-view></router-view>
        </div>
    </div>
</template>

<script>
import Toolbar from "../../Toolbar.vue";
import ToolbarButton from "../../ToolbarButton.vue";
import TriggersTable from "./TriggersTable.vue";
import { inject } from "vue";
import { storeToRefs } from "pinia";

export default {
    setup() {
        const circRulesStore = inject("circRulesStore");
        circRulesStore.init();
        const {
            updateTriggerCount,
            setAllRawRuleSets,
            setAllEffectiveRuleSets,
            setAllExhaustiveEffectiveRuleSets,
            isLastTrigger,
        } = circRulesStore;
        const {
            currentLibraryId,
            currentPatronCategoryId,
            currentItemTypeId,
            itemTypes,
            libraries,
            patronCategories,
            triggerCounts,
            allExhaustiveEffectiveRuleSets,
            allEffectiveRuleSets,
            storeInitialized,
        } = storeToRefs(circRulesStore);

        return {
            currentLibraryId,
            currentPatronCategoryId,
            currentItemTypeId,
            itemTypes,
            libraries,
            triggerCounts,
            patronCategories,
            updateTriggerCount,
            allExhaustiveEffectiveRuleSets,
            setAllRawRuleSets,
            setAllEffectiveRuleSets,
            setAllExhaustiveEffectiveRuleSets,
            allEffectiveRuleSets,
            isLastTrigger,
            storeInitialized,
            from_branch,
        };
    },
    data() {
        return {
            filtersInitialized: false,
            ruleSetInitialized: false,
            tabSelected: "Notice 1",
            showModal: false,
            displayAllApplicableRules: 1,
        };
    },
    beforeRouteEnter(to, from, next) {
        next(async vm => {
            vm.filtersInitialized = true;
            await vm.filterRuleSetsbySearchParam();
        });
    },
    methods: {
        async loadRuleSets() {
            this.ruleSetInitialized = false;
            await this.setAllRawRuleSets();
            this.updateTriggerCount();
            this.setAllEffectiveRuleSets();
            this.setAllExhaustiveEffectiveRuleSets();
            this.storeInitialized = true;
        },
        formatSelectedParams() {
            const selectedParams = {};
            selectedParams.effective = true;
            selectedParams.library_id = this.currentLibraryId ?? "*";
            if (this.currentPatronCategoryId) {
                selectedParams.patron_category_id =
                    this.currentPatronCategoryId;
            }
            if (this.currentItemTypeId) {
                selectedParams.item_type_id = this.currentItemTypeId;
            }
            return selectedParams;
        },
        async filterRuleSetsbySearchParam() {
            await this.loadRuleSets();

            const selectedParams = this.formatSelectedParams();
            const data = this.displayAllApplicableRules
                ? this.allExhaustiveEffectiveRuleSets
                : this.allEffectiveRuleSets;

            // handle searches for any patron category and item type combinations
            if (
                !selectedParams.patron_category_id &&
                !selectedParams.item_type_id
            ) {
                this.ruleSets = data;
                this.ruleSetInitialized = true;
                return;
            }

            // handle searches where only the item type is specified
            if (!selectedParams.patron_category_id) {
                this.ruleSets = data.filter(
                    ruleSet =>
                        ruleSet.context.item_type_id ===
                            selectedParams.item_type_id &&
                        ruleSet.context.library_id === selectedParams.library_id
                );
                this.ruleSetInitialized = true;
                return;
            }

            // handle searches where only the patron category is specified
            if (!selectedParams.item_type_id) {
                this.ruleSets = data.filter(
                    ruleSet =>
                        ruleSet.context.patron_category_id ===
                            selectedParams.patron_category_id &&
                        ruleSet.context.library_id === selectedParams.library_id
                );
                this.ruleSetInitialized = true;
                return;
            }

            // handle searches where both patron category and item type are specified and one specific rule is retrieved
            this.ruleSets = data.filter(
                ruleSet =>
                    ruleSet.context.item_type_id ===
                        selectedParams.item_type_id &&
                    ruleSet.context.patron_category_id ===
                        selectedParams.patron_category_id &&
                    ruleSet.context.library_id === selectedParams.library_id
            );
            this.ruleSetInitialized = true;
            return;
        },
        changeTabContent(e) {
            this.tabSelected = e.target.getAttribute("data-content");
        },
    },
    watch: {
        $route: {
            immediate: true,
            handler: function (newVal, oldVal) {
                this.showModal = newVal.meta && newVal.meta.showModal;
            },
        },
        "$route.query.refresh": {
            async handler(newVal) {
                if (newVal) {
                    await this.filterRuleSetsbySearchParam();
                }
            },
            immediate: true,
        },
    },
    components: { TriggersTable, Toolbar, ToolbarButton },
};
</script>

<style scoped>
.inline-block {
    display: inline-block;
    width: calc(100% - 90.25px);
    margin: 0 0 0 13px;
}
.page-section table {
    width: 100%;
    table-layout: fixed;
}
.page-section th,
.page-section td {
    width: 33%;
}
.page-section td {
    padding: 0.5em;
    vertical-align: top;
}
.v-select {
    display: block;
    background-color: white;
    margin: 10px;
    height: auto;
}
.vs__search,
.v__selected {
    display: inline-block;
    vertical-align: middle;
}
.active {
    cursor: pointer;
}
.toptabs {
    margin-bottom: 0;
}
.toggle-view-all-applicable-wrapper {
    margin: 10px;
}

.modal {
    position: fixed;
    z-index: 9998;
    display: table;
    transition: opacity 0.3s ease;
    left: 0px;
    top: 0px;
    width: 100%;
    height: 100%;
    box-shadow: 0 2px 8px rgba(0, 0, 0, 0.33);
    background-color: rgba(0, 0, 0, 0.33);
}
.modal-dialog,
.modal-dialog-centered,
.modal-lg {
    max-width: 90%;
    width: fit-content;
}
</style>
