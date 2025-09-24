<template>
    <fieldset
        class="rows"
        v-if="(ruleSetInitialized && editMode === 'edit') || editMode === 'add'"
        id="trigger-edit-form-general-section"
    >
        <legend v-if="editMode === 'add'">
            {{ $__("Add new trigger") + " " + triggerNumber }}
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
                <label for="restricts">{{ $__("Restricts checkouts") }}:</label>
                <div>
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="restricts-yes"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_restrict`]
                        "
                        :value="1"
                    />
                    {{ $__("Yes") }}
                    <input
                        @click="setAllowSubmission"
                        type="radio"
                        id="restricts-no"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_restrict`]
                        "
                        :value="0"
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
            <li>
                <label for="lost">{{ $__("Set Lost Value") }}:</label>
                <v-select
                    id="lost"
                    v-model="ruleSetToSubmit[`overdue_${triggerNumber}_lost`]"
                    label="description"
                    :reduce="val => val.authorised_value_id"
                    :options="lostValues"
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
                                          ]
                                      )
                                    : ''
                            "
                        />
                    </template>
                </v-select>
            </li>
            <li>
                <label for="charge"
                    >{{ $__("Charge replacement cost") }}:</label
                >
                <div>
                    <input
                        type="radio"
                        id="charge-yes"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_charge`]
                        "
                        :value="1"
                    />
                    {{ $__("Yes") }}
                    <input
                        type="radio"
                        id="charge-no"
                        v-model="
                            ruleSetToSubmit[`overdue_${triggerNumber}_charge`]
                        "
                        :value="0"
                    />
                    {{ $__("No") }}
                    <input
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
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_charge`
                            ] !== null
                        "
                    >
                        ({{
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_charge`
                            ] === 1
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
                        type="radio"
                        id="mark_returned-yes"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_mark_returned`
                            ]
                        "
                        :value="1"
                    />
                    {{ $__("Yes") }}
                    <input
                        type="radio"
                        id="mark_returned-no"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_mark_returned`
                            ]
                        "
                        :value="0"
                    />
                    {{ $__("No") }}
                    <input
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
                            ] !== null
                        "
                    >
                        ({{
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_mark_returned`
                            ] === 1
                                ? $__("Yes")
                                : $__("No")
                        }})
                    </span>
                </div>
            </li>
            <li>
                <label for="forgive_fine"
                    >{{ $__("Forgive overdue fine") }}:</label
                >
                <div>
                    <input
                        type="radio"
                        id="forgive_fine-yes"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_forgive_fine`
                            ]
                        "
                        :value="1"
                    />
                    {{ $__("Yes") }}
                    <input
                        type="radio"
                        id="forgive_fine-no"
                        v-model="
                            ruleSetToSubmit[
                                `overdue_${triggerNumber}_forgive_fine`
                            ]
                        "
                        :value="0"
                    />
                    {{ $__("No") }}
                    <input
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
                            ] !== null
                        "
                    >
                        ({{
                            fallbackRuleSet[
                                `overdue_${triggerNumber}_forgive_fine`
                            ] === 1
                                ? $__("Yes")
                                : $__("No")
                        }})
                    </span>
                </div>
            </li>
        </ol>
    </fieldset>
    <div v-else-if="editMode === 'add' || editMode === 'edit'">
        <p>{{ $__("Loading current action settings...") }}</p>
    </div>
</template>

<script>
export default {
    props: {
        ruleSetInitialized: { type: Boolean, required: true },
        editMode: { type: [String, Boolean], required: true },
        triggerNumber: { type: Number, required: true },
        ruleSetToSubmit: { type: Object, default: null },
        fallbackRuleSet: { type: Object, default: null },
        minDelay: { type: Number, required: true },
        maxDelay: { type: Number, required: true },
        setAllowSubmission: { type: Function, required: true },
        handleSetDelayToNull: { type: Function, required: true },
        incrementDelay: { type: Function, required: true },
        decrementDelay: { type: Function, required: true },
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
    padding-right: 40px;
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
    right: 22px;
    fill: var(--vs-controls-color);
    background-color: transparent;
    border: 0;
    font-size: 1.2em;
    color: #333;
    cursor: pointer;
    z-index: 2;
}

.button:active:hover,
.clear-btn:active:hover {
    background-color: #d4d4d4;
    border-color: #8c8c8c;
}

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

input[type="number"]::-webkit-inner-spin-button,
input[type="number"]::-webkit-outer-spin-button {
    -webkit-appearance: none;
    margin: 0;
}

input[type="number"] {
    -moz-appearance: textfield;
}

.numeric-input:focus,
.numeric-input:hover {
    border-color: #007bff;
    outline: none;
}
</style>
