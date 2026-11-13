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
        const { setMessage, setError } = inject("mainStore");

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

            client.displayItems
                .batchDelete(importData)
                .then(success => success.body)
                .then(body => {
                    const reader = body.getReader();

                    return new ReadableStream({
                        start(controller) {
                            return pump();

                            function pump() {
                                return reader.read().then(({ done, value }) => {
                                    // When no more data needs to be consumed, close the stream
                                    if (done) {
                                        controller.close();
                                        return;
                                    }

                                    // Enqueue the next data chunk into our target stream
                                    controller.enqueue(value);
                                    return pump();
                                });
                            }
                        },
                    });
                })
                .then(stream => new Response(stream))
                .then(response => response.text())
                .then(data => {
                    const body = JSON.parse(data);
                    if (body.job_id)
                        setMessage(
                            `${$__("Batch job successfully queued.")} <a href="/cgi-bin/koha/admin/background_jobs.pl?op=view&id=${body.job_id}" target="_blank">${$__("Click here to view job progress")}</a>`,
                            true
                        );
                    else
                        setMessage(
                            `${$__("Batch job successfully queued.")} <a href="/cgi-bin/koha/admin/background_jobs.pl" target="_blank">${$__("Click here to view job progress")}</a>`,
                            true
                        );
                    clearForm();
                })
                .catch(error => {
                    setError(
                        $__(
                            "Internal Server Error. Please check the browser console for diagnostic information."
                        ),
                        true
                    );
                    console.error(error);
                });
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
                error => {}
            );
        });
        return {
            setMessage,
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
