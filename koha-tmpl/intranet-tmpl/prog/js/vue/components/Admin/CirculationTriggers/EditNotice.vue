<template>
    <fieldset
        class="rows"
        v-if="(ruleSetInitialized && editMode === 'edit') || editMode === 'add'"
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
                    v-model="ruleSetToSubmit[`overdue_${triggerNumber}_notice`]"
                    label="name"
                    :reduce="type => type.code"
                    :options="filteredLetters"
                    :clearable="false"
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
                <ResetToFallback
                    :ruleSetToSubmit="ruleSetToSubmit"
                    :fallbackRuleSet="fallbackRuleSet"
                    :ruleName="`overdue_${triggerNumber}_notice`"
                    :setAllowSubmission="setAllowSubmission"
                />
            </li>
            <li
                v-if="
                    ruleSetToSubmit[`overdue_${triggerNumber}_notice`] !== '' &&
                    ruleSetToSubmit[`overdue_${triggerNumber}_notice`] !==
                        null &&
                    ruleSetToSubmit[`overdue_${triggerNumber}_notice`] !==
                        undefined
                "
            >
                <label for="mtt">{{ $__("Transport type(s)") }}:</label>
                <v-select
                    id="mtt"
                    v-model="ruleSetToSubmit[`overdue_${triggerNumber}_mtt`]"
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
                                ruleSetToSubmit[`overdue_${triggerNumber}_mtt`]
                                    .length === 0
                                    ? fallbackRuleSet?.[
                                          `overdue_${triggerNumber}_mtt`
                                      ]
                                    : ''
                            "
                            :required="
                                !ruleSetToSubmit[`overdue_${triggerNumber}_mtt`]
                                    ?.length
                            "
                        />
                    </template>
                </v-select>
                <span class="required">{{ $__("Required") }}</span>
            </li>
        </ol>
    </fieldset>
    <div v-else-if="editMode === 'add' || editMode === 'edit'">
        <p>{{ $__("Loading current notice settings...") }}</p>
    </div>
</template>

<script>
import ResetToFallback from "./ResetToFallback.vue";

export default {
    components: {
        ResetToFallback,
    },
    props: {
        ruleSetInitialized: { type: Boolean, required: true },
        editMode: { type: [String, Boolean], required: true },
        triggerNumber: { type: Number, required: true },
        ruleSetToSubmit: { type: Object, default: null },
        fallbackRuleSet: { type: Object, default: null },
        ruleSetInfo: { type: Object, required: true },
        filteredLetters: { type: Array, required: true },
        letters: { type: Array, required: true },
        transportTypes: { type: Array, required: true },
        setAllowSubmission: { type: Function, required: true },
    },
};
</script>
