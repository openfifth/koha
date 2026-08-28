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
        // reserve/request.pl already resolves a borrowernumber from either
        // a literal ?borrowernumber= or a ?findborrower=<cardnumber>
        // (an exact patron lookup only Perl can do - there's no
        // cardnumber-search equivalent in the Vue fetch layer) and hands
        // it down via holds.ts's app.provide("initialBorrowernumber", ...).
        // route.query.borrowernumber is checked first only as cheap
        // belt-and-braces - in the real page the two never disagree, since
        // the injected value already incorporates it.
        const initialBorrowernumber = inject("initialBorrowernumber", null);
        const patronId = ref(
            route.query.borrowernumber || initialBorrowernumber || null
        );

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
            // The embed is what gives ExpressBibLevelHold.vue a real
            // library.name to show as the pickup-library default, rather
            // than the blank label it'd get otherwise (there's no
            // branchname field on the patron response).
            APIClient.patron.patrons
                .get(id, { "x-koha-embed": "library" })
                .then(
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
