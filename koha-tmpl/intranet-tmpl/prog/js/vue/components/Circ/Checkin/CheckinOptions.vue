<template>
    <div class="circ-settings" style="display: block">
        <div
            v-if="policy.specify_return_date"
            class="date-select"
            id="return_date_override_fields"
        >
            <div class="hint">
                {{ $__("Specify return date (MM/DD/YYYY):") }}
            </div>
            <FlatPickrWrapper id="return-date-override" v-model="returnDate" />
            <div class="circ-setting">
                <input
                    id="return_date_override_remember"
                    v-model="rememberDate"
                    type="checkbox"
                />
                <label for="return_date_override_remember">{{
                    $__("Remember return date for next check in")
                }}</label>
            </div>
        </div>

        <div v-if="policy.exempt_fine" class="circ-setting">
            <input id="exemptcheck" v-model="exemptFine" type="checkbox" />
            <label for="exemptcheck">{{
                $__("Forgive overdue charges")
            }}</label>
        </div>

        <div class="circ-setting">
            <input id="dropboxcheck" v-model="dropboxMode" type="checkbox" />
            <label for="dropboxcheck">{{ $__("Book drop mode") }}</label>
        </div>

        <div v-if="policy.forgive_hold_fees" class="circ-setting">
            <input
                id="forgivemanualholdsexpire"
                v-model="forgiveHoldFees"
                type="checkbox"
            />
            <label for="forgivemanualholdsexpire">{{
                $__("Forgive fees for manually expired holds")
            }}</label>
        </div>
    </div>
</template>

<script>
import { computed, ref, watch } from "vue";
import { storeToRefs } from "pinia";
import { useCheckinStore } from "../../../stores/checkin.js";
import { $__ } from "@koha-vue/i18n";
import FlatPickrWrapper from "../../FlatPickrWrapper.vue";

export default {
    components: { FlatPickrWrapper },
    emits: ["update:options"],
    setup(props, { emit }) {
        const store = useCheckinStore();
        const { policy } = storeToRefs(store);

        const dropboxMode = ref(false);
        const exemptFine = ref(false);
        const forgiveHoldFees = ref(false);
        const returnDate = ref("");
        const rememberDate = ref(false);

        const today = computed(() => new Date().toISOString().split("T")[0]);

        // Emit consolidated options whenever any value changes
        function emitOptions() {
            emit("update:options", {
                dropbox_mode: dropboxMode.value,
                exempt_fine: exemptFine.value,
                forgive_hold_fees: forgiveHoldFees.value,
                return_date: returnDate.value || null,
            });
        }

        watch(dropboxMode, emitOptions);
        watch(exemptFine, emitOptions);
        watch(forgiveHoldFees, emitOptions);
        watch(returnDate, emitOptions);

        // If policy updates and exempt_fine is revoked, uncheck it
        watch(
            () => policy.value?.exempt_fine,
            newVal => {
                if (!newVal) exemptFine.value = false;
            }
        );

        function clearDate() {
            returnDate.value = "";
            rememberDate.value = false;
        }

        // After a checkin completes, clear date unless "remember" is checked
        function afterCheckin() {
            if (!rememberDate.value) {
                returnDate.value = "";
            }
        }

        return {
            policy,
            dropboxMode,
            exemptFine,
            forgiveHoldFees,
            returnDate,
            rememberDate,
            today,
            clearDate,
            afterCheckin,
            $__,
        };
    },
};
</script>
