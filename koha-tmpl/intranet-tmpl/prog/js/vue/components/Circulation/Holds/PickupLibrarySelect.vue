<template>
    <v-select
        v-model="model"
        label="name"
        :reduce="library => library.library_id"
        :options="options"
        :loading="loading"
        :clearable="false"
        @open="loadOptions"
    >
        <template v-slot:option="library">
            {{ library.name }}
            <i
                v-if="library.needs_override"
                class="fa fa-exclamation-circle text-warning"
                :title="
                    $__(
                        'This pickup location is not allowed according to circulation rules'
                    )
                "
            ></i>
        </template>
    </v-select>
</template>

<script>
import { computed, ref } from "vue";
import { APIClient } from "../../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "PickupLibrarySelect",
    props: {
        modelValue: { type: [String, Number], default: null },
        biblioId: { type: [String, Number], required: true },
        patronId: { type: [String, Number], required: true },
        // The patron's own library, already known by whoever renders this
        // field - lets the option render before the lazy full list ever
        // loads, and stays in the merged option list once it does, so the
        // current selection is never dropped out from under it.
        defaultLibraryId: { type: [String, Number], default: null },
        defaultLibraryName: { type: String, default: "" },
    },
    emits: ["update:modelValue"],
    setup(props, { emit }) {
        const model = computed({
            get: () => props.modelValue,
            set: value => emit("update:modelValue", value),
        });

        const pickupLocations = ref([]);
        const loading = ref(false);
        const loaded = ref(false);

        const options = computed(() => {
            const seed = {
                library_id: props.defaultLibraryId,
                name: props.defaultLibraryName,
                needs_override: false,
            };
            const byId = new Map([[seed.library_id, seed]]);
            pickupLocations.value.forEach(loc => byId.set(loc.library_id, loc));
            return [...byId.values()];
        });

        // Opening the dropdown is the only thing that needs the full,
        // server-searched list - the default option above already covers
        // the common case with no call at all.
        const loadOptions = () => {
            if (loaded.value || loading.value) return;
            loading.value = true;
            APIClient.circulation.pickupLocations
                .biblio(props.biblioId, { patron_id: props.patronId })
                .then(
                    result => {
                        pickupLocations.value = result.results || result;
                        loaded.value = true;
                        loading.value = false;
                    },
                    () => {
                        loading.value = false;
                    }
                );
        };

        return { model, options, loading, loadOptions };
    },
};
</script>

<style></style>
