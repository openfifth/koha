<template>
    <div
        id="patronSelfRenewal"
        class="modal modal-full"
        tabindex="-1"
        role="dialog"
        aria-labelledby="patronSelfRenewal"
        aria-hidden="true"
    >
        <div class="modal-dialog modal-xl">
            <div v-if="initialized" class="modal-content">
                <div class="modal-header">
                    <h1 class="modal-title">
                        {{ $__("Patron self-renewal") }}
                    </h1>
                    <button
                        type="button"
                        class="btn-close"
                        data-bs-dismiss="modal"
                        aria-label="Close"
                    ></button>
                </div>
                <div class="modal-body">
                    <VerificationChecks
                        v-if="activeStep === 'verification'"
                        :renewalSettings="renewalSettings"
                        @verification-successful="onVerificationSuccess"
                    />
                    <VerificationChecks
                        v-if="activeStep === 'confirmation'"
                        :informationMessage="
                            $__('Are you sure you want to renew your account?')
                        "
                        :renewalSettings="renewalSettings"
                        @verification-successful="submitRenewal"
                    />
                    <div v-if="activeStep === 'detailsCheck'">
                        <legend>
                            {{ $__("Confirm your account details") }}
                        </legend>
                        <div class="detail_confirmation">
                            <span>{{
                                $__(
                                    "You need to confirm your personal details to proceed with your account renewal."
                                )
                            }}</span>
                            <button
                                class="btn btn-default"
                                @click="proceedToDetailsVerification()"
                            >
                                {{ $__("Continue") }}
                            </button>
                        </div>
                    </div>
                </div>
                <div class="modal-footer">
                    <button
                        type="button"
                        class="btn btn-default cancel"
                        data-bs-dismiss="modal"
                    >
                        {{ $__("Close") }}
                    </button>
                </div>
            </div>
        </div>
    </div>
</template>

<script>
import { onBeforeMount, ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import VerificationChecks from "./VerificationChecks.vue";
import { $__ } from "@koha-vue/i18n";

export default {
    components: { VerificationChecks },
    props: {
        patron: String,
    },
    setup(props) {
        const initialized = ref(false);
        const activeStep = ref(null);
        const renewalSettings = ref({
            defaultErrorMessage: $__(
                "You are not able to self-renew with the provided information. Please visit your library to proceed with your renewal."
            ),
        });

        onBeforeMount(() => {
            const client = APIClient.patron;
            client.self_renewal.start(props.patron).then(
                response => {
                    renewalSettings.value = {
                        ...renewalSettings.value,
                        ...response.self_renewal_settings,
                    };
                    activeStep.value = response.self_renewal_settings
                        .self_renewal_information_message
                        ? "verification"
                        : response.self_renewal_settings.opac_patron_details ===
                            "1"
                          ? "detailsCheck"
                          : "confirmation";
                    initialized.value = true;
                },
                error => {}
            );
        });

        const proceedToDetailsVerification = () => {
            window.location.href =
                "/cgi-bin/koha/opac-memberentry.pl?self_renewal=1";
        };

        const onVerificationSuccess = () => {
            if (renewalSettings.value.opac_patron_details === "1") {
                activeStep.value = "detailsCheck";
            } else {
                activeStep.value = "confirmation";
            }
        };

        const submitRenewal = () => {
            const client = APIClient.patron;
            client.self_renewal.submit(props.patron, {}).then(
                response => {
                    let newLocation =
                        "/cgi-bin/koha/opac-user.pl?self_renewal_success=" +
                        response.expiry_date;
                    if (response.confirmation_sent) {
                        newLocation += "&confirmation_sent=1";
                    }
                    document.location = newLocation;
                },
                error => {
                    document.location =
                        "/cgi-bin/koha/opac-user.pl?self_renewal_success=0";
                }
            );
        };

        return {
            initialized,
            activeStep,
            renewalSettings,
            onVerificationSuccess,
            proceedToDetailsVerification,
            submitRenewal,
        };
    },
};
</script>

<style scoped>
.detail_confirmation {
    display: flex;
    flex-direction: column;
    gap: 1em;
}
.detail_confirmation button {
    display: flex;
    flex-direction: column;
    gap: 1em;
    width: 7em;
}
</style>
