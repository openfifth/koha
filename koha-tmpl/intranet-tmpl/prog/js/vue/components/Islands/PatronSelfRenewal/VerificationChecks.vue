<template>
    <fieldset class="rows" v-if="!verificationFailure">
        <span class="verification_question">{{ activeCheck }}</span>
        <div class="verification_actions">
            <button class="btn btn-success" @click="verificationPassed()">
                {{ $__("Yes") }}
            </button>
            <button class="btn btn-default" @click="verificationFailed()">
                {{ $__("No") }}
            </button>
        </div>
    </fieldset>
    <span class="error" v-else>{{ errorMessage }}</span>
</template>

<script>
import { computed, ref } from "vue";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        renewalSettings: Object,
        confirmation: Boolean,
    },
    emits: ["verification-successful"],
    setup(props, { emit }) {
        const checkCount = ref(
            props.renewalSettings.self_renewal_information_messages.length
        );
        const completedCount = ref(0);
        const verificationFailure = ref(false);

        const activeCheck = ref(
            props.renewalSettings.self_renewal_information_messages[0]
        );

        const verificationPassed = () => {
            if (completedCount.value === checkCount.value - 1) {
                emit("verification-successful");
            } else {
                completedCount.value++;
                activeCheck.value =
                    props.renewalSettings.self_renewal_information_messages[
                        completedCount.value
                    ];
            }
        };
        const verificationFailed = () => {
            verificationFailure.value = true;
        };

        const errorMessage = computed(() => {
            const { self_renewal_failure_message, defaultErrorMessage } =
                props.renewalSettings;
            return self_renewal_failure_message || defaultErrorMessage;
        });

        return {
            checkCount,
            activeCheck,
            verificationPassed,
            verificationFailed,
            verificationFailure,
            errorMessage,
            completedCount,
        };
    },
};
</script>

<style scoped>
.rows {
    display: flex;
    flex-direction: column;
}
.verification_actions {
    display: flex;
    gap: 1em;
}
.verification_actions button {
    width: 5em;
}
.verification_question {
    margin-bottom: 2em;
    font-size: 100%;
}
</style>
