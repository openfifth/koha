<template>
    <h2>{{ $__("Batch remove items from list") }}</h2>
    <div class="page-section" id="list">
        <form @submit="batchRemove($event)">
            <fieldset class="rows" id="display_list">
                <h3>{{ $__("Specify items to remove") }}:</h3>
                <ol>
                    <li v-for="attr in formFields" :key="attr.name">
                        <FormElement
                            :resource="resource"
                            :attr="attr"
                            :options="displays"
                        />
                    </li>
                </ol>
            </fieldset>
            <fieldset class="action">
                <ButtonSubmit :title="$__('Save')" />
                <router-link
                    :to="{
                        name: 'DisplaysList',
                    }"
                    role="button"
                    class="cancel"
                    >{{ $__("Cancel") }}</router-link
                >
            </fieldset>
        </form>
    </div>
</template>

<script>
import { ref, inject, onBeforeMount } from "vue";
import ButtonSubmit from "../ButtonSubmit.vue";
import FormElement from "../FormElement.vue";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        embedded: { type: Boolean, default: false },
        embedEvent: Function,
    },
    setup(props) {
        const { setMessage, setWarning } = inject("mainStore");

        const displays = ref([]);
        const emptyResource = () => ({
            barcodes: null,
            display_id: null,
        });
        const resource = ref(emptyResource());

        const formFields = [
            {
                name: "barcodes",
                label: $__("Item barcodes"),
                type: "textarea",
                required: true,
                textAreaRows: 10,
                textAreaCols: 25,
                toolTip: $__("List of item barcodes, one per line"),
            },
            {
                name: "display_id",
                label: $__("From the following display"),
                type: "select",
                required: true,
                selectLabel: "display_name",
                requiredKey: "display_id",
            },
        ];

        const batchRemove = event => {
            event.preventDefault();

            const barcodeList = resource.value.barcodes
                .split("\n")
                .map(n => n.trim())
                .filter(n => n !== "");

            const client = APIClient.display;
            const importData = {
                display_id: resource.value.display_id,
                barcodes: barcodeList,
            };

            // The HTTP client already shows the reason when a request fails
            client.displayItems.batchDelete(importData).then(
                success => {
                    if (success.job_id)
                        setMessage(
                            `${$__("Batch job successfully queued.")} <a href="/cgi-bin/koha/admin/background_jobs.pl?op=view&id=${success.job_id}" target="_blank">${$__("Click here to view job progress")}</a>`,
                            true
                        );
                    else
                        setWarning(
                            $__(
                                "Batch job failed to queue. Please check your list, and try again."
                            ),
                            true
                        );
                    clearForm();
                },
                error => console.error(error)
            );
        };
        const clearForm = () => {
            resource.value = emptyResource();
        };

        onBeforeMount(() => {
            const client = APIClient.display;
            client.displays.getAll().then(
                result => {
                    displays.value = result;
                },
                error => console.error(error)
            );
        });
        return {
            setMessage,
            setWarning,
            displays,
            resource,
            formFields,
            batchRemove,
            clearForm,
        };
    },
    components: {
        ButtonSubmit,
        FormElement,
    },
    name: "DisplaysBatchRemoveItems",
};
</script>

<style scoped>
label {
    margin: 0px 10px 0px 0px;
}
</style>
