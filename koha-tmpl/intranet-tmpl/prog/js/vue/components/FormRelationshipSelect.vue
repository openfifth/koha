<template>
    <v-select
        :getOptionLabel="
            relatedResource => relatedResource[relationshipOptionLabelAttr]
        "
        :id="name"
        :reduce="reduceOption"
        :options="relatedResourcesOptions"
        :required="required && !resource[name]"
        :multiple="allowMultipleChoices"
        :filterable="!serverSearch"
        :filter-by="filterRelatedResourcesOptions"
        v-model="resource[name]"
        :disabled="shouldBeDisabled"
        :placeholder="
            serverSearch
                ? searchPlaceholder
                : !relatedResourcesLoaded
                  ? $__('Loading...')
                  : ''
        "
        @search="onSearch"
    >
        <template v-slot:option="relatedResource">
            <slot name="option" v-bind="relatedResource">
                {{ relatedResource[relationshipOptionLabelAttr] }}
            </slot>
        </template>
        <template #search="{ attributes, events }">
            <input
                :required="required && !resource[name]"
                class="vs__search"
                v-bind="attributes"
                v-on="events"
            />
        </template>
    </v-select>
</template>

<script>
import { computed, onBeforeMount, onBeforeUnmount, ref } from "vue";
import vSelect from "vue-select";
export default {
    components: { "v-select": vSelect },
    props: {
        relationshipOptionLabelAttr: String | null,
        relationshipAPIClient: Object | null,
        resource: Object | null,
        name: String | null,
        allowMultipleChoices: Boolean | null,
        relationshipRequiredKey: String | null,
        disabled: Boolean | false,
        required: Boolean | false,
        query: {
            type: Object,
            default: {},
        },
        serverSearch: Boolean | false,
        searchQueryBuilder: {
            type: Function,
            default: null,
        },
        searchParams: {
            type: Object,
            default: () => ({}),
        },
        searchMinLength: {
            type: Number,
            default: 3,
        },
        searchPlaceholder: {
            type: String,
            default: "",
        },
    },
    setup(props) {
        const relatedResources = ref(null);
        const relatedResourcesLoaded = ref(false);
        let searchTimer = null;
        let searchSequence = 0;

        onBeforeMount(() => {
            if (props.serverSearch) {
                relatedResources.value = [];
                relatedResourcesLoaded.value = true;
                return;
            }
            const relatedResourcesClient = props.relationshipAPIClient;
            relatedResourcesClient.getAll(props.query).then(
                result => {
                    relatedResources.value = result;
                    relatedResourcesLoaded.value = true;
                },
                error => {}
            );
        });
        onBeforeUnmount(() => clearTimeout(searchTimer));

        // v-select 'search' event emits: this.$emit("search", this.search, this.toggleLoading)
        const onSearch = (searchTerm, loading) => {
            if (!props.serverSearch) return;
            clearTimeout(searchTimer);
            if (
                searchTerm.length < props.searchMinLength &&
                !/^\d+$/.test(searchTerm)
            ) {
                relatedResources.value = [];
                loading(false);
                return;
            }
            loading(true);
            searchTimer = setTimeout(() => {
                const currentSearchNumber = ++searchSequence;
                props.relationshipAPIClient
                    .getAll(props.searchQueryBuilder(searchTerm), {
                        // getAll would otherwise send _per_page=-1 (all rows)
                        _per_page: 20,
                        ...props.searchParams,
                    })
                    .then(
                        result => {
                            if (currentSearchNumber != searchSequence) return;
                            relatedResources.value = result;
                            loading(false);
                        },
                        error => loading(false)
                    );
            }, 300);
        };

        const reduceOption = relatedResource =>
            props.relationshipRequiredKey
                ? relatedResource[props.relationshipRequiredKey]
                : relatedResource;

        const relatedResourcesOptions = computed(() => {
            return relatedResources.value?.map(resource => ({
                ...resource,
                full_search: resource[props.relationshipOptionLabelAttr],
            }));
        });
        const shouldBeDisabled = computed(() => {
            return props.disabled || !relatedResourcesLoaded.value;
        });

        const filterRelatedResourcesOptions = (resource, label, search) => {
            return (
                (resource.full_search || "")
                    .toLocaleLowerCase()
                    .indexOf(search.toLocaleLowerCase()) > -1
            );
        };

        return {
            relatedResources,
            relatedResourcesLoaded,
            relatedResourcesOptions,
            reduceOption,
            shouldBeDisabled,
            filterRelatedResourcesOptions,
            onSearch,
        };
    },
};
</script>
