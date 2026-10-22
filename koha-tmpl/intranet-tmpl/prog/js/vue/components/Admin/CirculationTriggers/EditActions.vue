<template>
    <fieldset
        class="rows"
        v-if="(ruleSetInitialized && editMode === 'edit') || editMode === 'add'"
        id="trigger-edit-form-lost-section"
    >
        <legend>
            {{
                $__x("Lost items for trigger {triggerNumber}", {
                    triggerNumber,
                })
            }}
        </legend>
        <div class="page-section bg-info">
            <p>
                {{
                    $__x(
                        "For each overdue item, Koha marks it lost, forgives its overdue fine, charges for it and checks it in using the triggers set up for {library}.",
                        { library: lostLibrary }
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
                    href="/cgi-bin/koha/admin/preferences.pl?op=search&searchfield=LostChargesControl"
                    >LostChargesControl</a
                ><template v-if="followsItemLibrary"
                    >,
                    <a
                        href="/cgi-bin/koha/admin/preferences.pl?op=search&searchfield=HomeOrHoldingBranch"
                        >HomeOrHoldingBranch</a
                    ></template
                >
            </p>
        </div>
        <ol>
            <li>
                <label for="lost">{{ $__("Set Lost Value") }}:</label>
                <v-select
                    id="lost"
                    v-model="ruleSetToSubmit[`overdue_${triggerNumber}_lost`]"
                    label="description"
                    :reduce="val => val.value"
                    :options="lostValues"
                    @update:modelValue="setAllowSubmission"
                >
                    <template #search="{ attributes, events }">
                        <input
                            class="vs__search"
                            v-bind="attributes"
                            v-on="events"
                            :placeholder="
                                ruleSetToSubmit[
                                    `overdue_${triggerNumber}_lost`
                                ] === null ||
                                ruleSetToSubmit[
                                    `overdue_${triggerNumber}_lost`
                                ] === undefined
                                    ? handleLost(
                                          fallbackRuleSet[
                                              `overdue_${triggerNumber}_lost`
                                          ]?.value,
                                          lostValues
                                      )
                                    : ''
                            "
                        />
                    </template>
                </v-select>
                <ResetToFallback
                    :ruleSetToSubmit="ruleSetToSubmit"
                    :fallbackRuleSet="fallbackRuleSet"
                    :ruleName="`overdue_${triggerNumber}_lost`"
                    :setAllowSubmission="setAllowSubmission"
                />
            </li>
            <li>
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
            <li>
                <label for="charge"
                    >{{ $__("Charge replacement cost") }}:</label
                >
                <div>
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="charge-yes"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_charge`]
                        "
                        :value="'1'"
                    />
                    {{ $__("Yes") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="charge-no"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_charge`]
                        "
                        :value="'0'"
                    />
                    {{ $__("No") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="charge-fallback"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_charge`]
                        "
                        :value="null"
                    />
                    {{ $__("Fallback to default") }}
                    <span
                        v-if="
                            fallbackRuleSet[`overdue_${triggerNumber}_charge`]
                                ?.value !== null
                        "
                    >
                        ({{
                            fallbackRuleSet[`overdue_${triggerNumber}_charge`]
                                ?.value === "1"
                                ? $__("Yes")
                                : $__("No")
                        }})
                    </span>
                </div>
            </li>
            <li>
                <label for="mark_returned"
                    >{{ $__("Mark as returned") }}:</label
                >
                <div>
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="mark_returned-yes"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_mark_returned`
                            ]
                        "
                        :value="'1'"
                    />
                    {{ $__("Yes") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="mark_returned-no"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_mark_returned`
                            ]
                        "
                        :value="'0'"
                    />
                    {{ $__("No") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="mark_returned-fallback"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_mark_returned`
                            ]
                        "
                        :value="null"
                    />
                    {{ $__("Fallback to default") }}
                    <span
                        v-if="
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_mark_returned`
                            ]?.value !== null
                        "
                    >
                        ({{
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_mark_returned`
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
        <p>{{ $__("Loading current lost item settings...") }}</p>
    </div>
</template>

<script>
import ResetToFallback from "./ResetToFallback.vue";
import { describeLostChargesControl } from "@koha-vue/composables/circulation-rules";

export default {
    components: { ResetToFallback },
    setup() {
        return {
            followsItemLibrary: lost_charges_control !== "PatronLibrary",
            lostLibrary: describeLostChargesControl(
                lost_charges_control,
                home_or_holding_branch
            ),
        };
    },
    props: {
        ruleSetInitialized: { type: Boolean, required: true },
        editMode: { type: [String, Boolean], required: true },
        triggerNumber: { type: Number, required: true },
        ruleSetToSubmit: { type: Object, default: null },
        fallbackRuleSet: { type: Object, default: null },
        setAllowSubmission: { type: Function, required: true },
        handleLost: { type: Function, required: true },
        lostValues: { type: Array, required: true },
    },
};
</script>

<style scoped>
li {
    display: flex;
    align-items: center;
}
</style>
