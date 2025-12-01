<template>
    <h2>{{ $__("Batch add items from list") }}</h2>
    <div class="page-section" id="list">
        <form @submit="batchAdd($event)">
            <fieldset class="rows" id="display_list">
                <h3>{{ $__("Sepcify items to add") }}:</h3>
                <ol>
                    <li>
                        <label for="barcodes">{{ $__("Item barcodes") }}:</label>
                        <textarea
                            id="barcodes"
                            v-model="barcodes"
                            label="barcodes"
                            :cols="`25`"
                            :rows="`10`"
                            :required="!barcodes"
                        />
                        <span class="required">{{ $__("Required") }}</span>
                        <div class="hint">
                            {{ $__("List of item barcodes, one per line") }}<br />
                        </div>
                    </li>
                    <li>
                        <label for="display_id"
                            >{{ $__("To the following display") }}:</label
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
                    <li>
                        <label for="date_remove"
                            >{{ $__("To remove on this date") }}:</label
                        >
                        <FlatPickrWrapper
                            :id="`date_remove`"
                            :name="`date_remove`"
                            v-model="date_remove"
                            label="date_remove"
                        />
                    </li>
                </ol>
            </fieldset>
            <fieldset class="action">
                <ButtonSubmit
                    :title="$__('Save')"
                />
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
import FlatPickrWrapper from "@koha-vue/components/FlatPickrWrapper.vue";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    props: {
        routeAction: String,
        component: String,
        embedded: { type: Boolean, default: false },
        componentPropData: Object,
        embedEvent: Function,
    },
    setup(props) {
        const DisplayStore = inject("DisplayStore");
        const { config } = storeToRefs(DisplayStore);
        const { setMessage, setWarning, setError } = inject("mainStore");

        const displays = ref([]);
        const display_id = ref(null);
        const barcodes = ref(null);
        const date_remove = ref(null);

        const batchAdd = event => {
            event.preventDefault();

            barcodes.value = barcodes.value
            .split("\n")
            .map(n => Number(n))
            .filter(n => {
                if (n == '')
                    return false;

                return true;
            });

            const client = APIClient.display;
            const importData = {
                display_id: display_id.value,
                barcodes: barcodes.value,
            };
            if (date_remove.value != null)
                importData.date_remove = date_remove.value;

            client.displayItems.batchAdd(importData).then(
                success => {
                    if (success.job_id)
                        setMessage(`${$__('Batch job successfully queued.')} <a href="/cgi-bin/koha/admin/background_jobs.pl?op=view&id=${success.job_id}" target="_blank">${$__('Click here to view job progress')}</a>`, true);

                    if (!success.job_id)
                        setWarning($__('Batch job failed to queue. Please check your list, and try again.'), true);
                },
                error => {
                    setError($__('Internal Server Error. Please check the browser console for diagnostic information.'), true);
                    console.error(error);
                },
            );
            clearForm();
        };
        const clearForm = () => {
            display_id.value = null;
            barcodes.value = null;
            date_remove.value = null;
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
            setWarning,
            displays,
            display_id,
            barcodes,
            date_remove,
            batchAdd,
            clearForm,
        };
    },
    components: {
        ButtonSubmit,
        FlatPickrWrapper,
    },
    name: "DisplaysBatchAddItems",
};
</script>

<style scoped>
label {
    margin: 0px 10px 0px 0px;
}
</style>
