<template>
    <h2>{{ $__("Batch remove items from list") }}</h2>
    <div class="page-section" id="list">
        <form @submit="batchRemove($event)">
            <fieldset class="rows" id="display_list">
                <h3>{{ $__("Specify items to remove") }}:</h3>
                <ol>
                    <li>
                        <label for="barcodes"
                            >{{ $__("Item barcodes") }}:</label
                        >
                        <textarea
                            id="barcodes"
                            v-model="barcodes"
                            label="barcodes"
                            :cols="`25`"
                            :rows="`10`"
                            :required="!barcodes"
                        />
                        <span class="required">{{ $__("Required") }}</span>
                        <ToolTip
                            :toolTip="
                                $__('List of item barcodes, one per line')
                            "
                        ></ToolTip>
                    </li>
                    <li>
                        <label for="display_id"
                            >{{ $__("From the following display") }}:</label
                        >
                        <v-select
                            id="display_id"
                            v-model="display_id"
                            label="display_name"
                            :reduce="d => d.display_id"
                            :options="displays"
                            :clearable="false"
                            :required="!display_id"
                        >
                            <template #search="{ attributes, events }">
                                <input
                                    :required="!display_id"
                                    class="vs__search"
                                    v-bind="attributes"
                                    v-on="events"
                                />
                            </template>
                        </v-select>
                        <span class="required">{{ $__("Required") }}</span>
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
import ToolTip from "../ToolTip.vue";
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
        const display_id = ref(null);
        const barcodes = ref(null);

        const batchRemove = event => {
            event.preventDefault();

            const barcodeList = barcodes.value
                .split("\n")
                .map(n => n.trim())
                .filter(n => n !== "");

            const client = APIClient.display;
            const importData = {
                display_id: display_id.value,
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
            display_id.value = null;
            barcodes.value = null;
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
            display_id,
            barcodes,
            batchRemove,
            clearForm,
        };
    },
    components: {
        ButtonSubmit,
        ToolTip,
    },
    name: "DisplaysBatchRemoveItems",
};
</script>

<style scoped>
label {
    margin: 0px 10px 0px 0px;
}
</style>
