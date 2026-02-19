<template>
    <fieldset class="rows" v-if="!verificationFailure">
        <span class="verification_question">{{ verificationCheck }}</span>
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
        informationMessage: String,
    },
    emits: ["verification-successful"],
    setup(props, { emit }) {
        const verificationFailure = ref(false);
        const verificationCheck = ref(
            props.informationMessage ||
                props.renewalSettings.self_renewal_information_message
        );

        const verificationPassed = () => {
            emit("verification-successful");
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
            verificationCheck,
            verificationPassed,
            verificationFailed,
            verificationFailure,
            errorMessage,
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
