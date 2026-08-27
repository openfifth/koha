import { watch } from "vue";
import { storeToRefs } from "pinia";
import { useMainStore } from "../stores/main.js";
import { $__ } from "@koha-vue/i18n";

export const useHoldOverrideConfirmation = () => {
    const mainStore = useMainStore();
    const { setConfirmationDialog } = mainStore;
    const { confirmation } = storeToRefs(mainStore);

    // reasons: Array<{ code, label }> - Resolves once the dialog
    // closes: with the override codes if confirmed, or null if the dialog
    // was cancelled/dismissed without confirming.
    const requestHoldOverride = reasons =>
        new Promise(resolve => {
            let accepted = false;

            setConfirmationDialog(
                {
                    title: $__("Override required"),
                    message:
                        "<ul>" +
                        reasons.map(r => `<li>${r.label}</li>`).join("") +
                        "</ul>",
                    accept_label: $__("Override"),
                    cancel_label: $__("Cancel"),
                },
                () => {
                    accepted = true;
                    resolve(reasons.map(r => r.code));
                }
            );

            // setConfirmationDialog's own accept wrapper and Dialog.vue's
            // cancel/dismiss button both end up clearing
            // mainStore.confirmation. The accept path above already
            // resolved by the time this fires, so this only ever catches
            // the cancel case.
            const stop = watch(confirmation, (newValue, oldValue) => {
                if (!newValue && oldValue) {
                    stop();
                    if (!accepted) resolve(null);
                }
            });
        });

    return { requestHoldOverride };
};
