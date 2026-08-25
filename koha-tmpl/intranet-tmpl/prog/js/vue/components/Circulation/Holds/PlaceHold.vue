<template>
    <div v-if="biblio" class="page-section">
        <h1>{{ $__("Place a hold on %s").format(biblio.title) }}</h1>

        <div class="mb-3">
            <label for="place-hold-patron">{{ $__("Patron") }}: </label>
            <PatronAutoComplete
                id="place-hold-patron"
                v-model="patronId"
                :placeholder="$__('Search for a patron')"
            />
        </div>

        <ExpressBibLevelHold v-if="patron" :biblio="biblio" :patron="patron" />
    </div>
</template>

<script>
import { inject, onBeforeMount, ref, watch } from "vue";
import { useRoute, useRouter } from "vue-router";
import { APIClient } from "../../../fetch/api-client.js";
import PatronAutoComplete from "../../PatronAutoComplete.vue";
import ExpressBibLevelHold from "./ExpressBibLevelHold.vue";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "PlaceHold",
    components: { PatronAutoComplete, ExpressBibLevelHold },
    setup() {
        const route = useRoute();
        const router = useRouter();
        const mainStore = inject("mainStore");
        const { loading, loaded, setError } = mainStore;

        // reserve/request.pl accepts a repeated biblionumber param for a
        // multi-record hold; vue-router hands that back as an array. Only
        // the single-record case is handled here - take the first value
        // rather than let the array shape reach the API call broken.
        const queryBiblionumber = Array.isArray(route.query.biblionumber)
            ? route.query.biblionumber[0]
            : route.query.biblionumber;

        const biblio = ref(null);
        const patron = ref(null);
        const patronId = ref(route.query.borrowernumber || null);

        onBeforeMount(() => {
            loading();
            APIClient.biblio.get(queryBiblionumber).then(
                result => {
                    biblio.value = result;
                    loaded();
                },
                error => {
                    loaded();
                    setError(error);
                }
            );
        });

        const loadPatron = id => {
            if (!id) {
                patron.value = null;
                return;
            }
            APIClient.patron.patrons.get(id).then(
                result => (patron.value = result),
                error => setError(error)
            );
        };

        // borrowernumber lives in the URL, not just component state, so
        // navigating back here restores the same patron without asking
        // again. The query is spread first so searchid and anything else
        // already on the URL (this page is reached from search results,
        // among other places) survives untouched.
        watch(patronId, id => {
            const query = { ...route.query };
            if (id) {
                query.borrowernumber = id;
            } else {
                delete query.borrowernumber;
            }
            router.replace({ name: "PlaceHold", query });
            loadPatron(id);
        });

        loadPatron(patronId.value);

        return { biblio, patron, patronId };
    },
};
</script>

<style></style>
