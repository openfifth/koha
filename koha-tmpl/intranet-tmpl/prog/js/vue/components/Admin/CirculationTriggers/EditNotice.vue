<template>
    <fieldset
        class="rows"
        v-if="(ruleSetInitialized && editMode === 'edit') || editMode === 'add'"
        id="trigger-edit-form-notice-section"
    >
        <legend v-if="ruleSetInfo.triggerCount < triggerNumber">
            {{ $__("Notice, restriction and fine for trigger") }}
            {{ " " + triggerNumber }}
        </legend>
        <legend v-else>
            {{ $__("Edit notice, restriction and fine for trigger") }}
            {{ " " + triggerNumber }}
        </legend>
        <div class="page-section bg-info">
            <p>
                {{
                    $__x(
                        "For each overdue item, Koha sends the notice, restricts the patron and forgives the fine using the triggers set up for {library}.",
                        { library: noticeLibrary }
                    )
                }}
                {{
                    $__(
                        "If closed days are skipped, Koha counts only the days that library is open."
                    )
                }}
            </p>
            <p>
                {{ $__("To use a different library, change:") }}
                <a
                    href="/cgi-bin/koha/admin/preferences.pl?op=search&searchfield=OverdueNoticeFrom"
                    >OverdueNoticeFrom</a
                >
            </p>
        </div>
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
                    @update:modelValue="handleNoticeChange"
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
                                              ]?.value
                                      )?.name ||
                                      fallbackRuleSet?.[
                                          `overdue_${triggerNumber}_notice`
                                      ]?.value
                                    : ''
                            "
                        />
                    </template>
                </v-select>
                <ResetToFallback
                    :ruleSetToSubmit="ruleSetToSubmit"
                    :fallbackRuleSet="fallbackRuleSet"
                    :ruleName="`overdue_${triggerNumber}_notice`"
                    :setAllowSubmission="handleNoticeChange"
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
                                ] === undefined
                                    ? fallbackRuleSet?.[
                                          `overdue_${triggerNumber}_mtt`
                                      ]?.value
                                    : ''
                            "
                            :required="
                                !ruleSetToSubmit[`overdue_${triggerNumber}_mtt`]
                                    ?.length
                            "
                        />
                    </template>
                </v-select>
                <ResetToFallback
                    :ruleSetToSubmit="ruleSetToSubmit"
                    :fallbackRuleSet="fallbackRuleSet"
                    :ruleName="`overdue_${triggerNumber}_mtt`"
                    :setAllowSubmission="setAllowSubmission"
                />
                <span class="required">{{ $__("Required") }}</span>
            </li>
            <li class="radio-row">
                <label for="restricts">{{ $__("Restricts checkouts") }}:</label>
                <div>
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="restricts-yes"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_restrict`]
                        "
                        :value="'1'"
                    />
                    {{ $__("Yes") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="restricts-no"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_restrict`]
                        "
                        :value="'0'"
                    />
                    {{ $__("No") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="restricts-fallback"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_restrict`]
                        "
                        :value="null"
                    />
                    {{ $__("Fallback to default") }}
                    <span
                        v-if="
                            fallbackRuleSet?.[
                                `overdue_${triggerNumber}_restrict`
                            ]?.value !== null
                        "
                    >
                        ({{
                            fallbackRuleSet?.[
                                `overdue_${triggerNumber}_restrict`
                            ]?.value === "1"
                                ? $__("Yes")
                                : $__("No")
                        }})
                    </span>
                </div>
            </li>
            <li class="radio-row">
                <label for="forgive_fine"
                    >{{ $__("Forgive overdue fine") }}:</label
                >
                <div>
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="forgive_fine-yes"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_forgive_fine`
                            ]
                        "
                        :value="'1'"
                    />
                    {{ $__("Yes") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="forgive_fine-no"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_forgive_fine`
                            ]
                        "
                        :value="'0'"
                    />
                    {{ $__("No") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="forgive_fine-fallback"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_forgive_fine`
                            ]
                        "
                        :value="null"
                    />
                    {{ $__("Fallback to default") }}
                    <span
                        v-if="
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_forgive_fine`
                            ]?.value !== null
                        "
                    >
                        ({{
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_forgive_fine`
                            ]?.value === "1"
                                ? $__("Yes")
                                : $__("No")
                        }})
                    </span>
                </div>
            </li>
        </ol>
    </fieldset>
    <div v-else-if="editMode === 'add' || editMode === 'edit'">
        <p>{{ $__("Loading current notice settings...") }}</p>
    </div>
</template>

<script>
import ResetToFallback from "./ResetToFallback.vue";
import { describeOverdueNoticeFrom } from "@koha-vue/composables/circulation-rules";

export default {
    components: { ResetToFallback },
    setup() {
        return {
            noticeLibrary: describeOverdueNoticeFrom(from_branch),
        };
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
        handleNoticeChange: { type: Function, required: true },
    },
};
</script>

<style scoped>
li.radio-row {
    display: flex;
    align-items: center;
}
</style>
