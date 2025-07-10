<template>
    <v-select
        :getOptionLabel="
            relatedResource => relatedResource[relationshipOptionLabelAttr]
        "
        :id="name"
        :reduce="relatedResource => relatedResource[relationshipRequiredKey]"
        :options="relatedResourcesOptions"
        :required="required && !resource[name]"
        :multiple="allowMultipleChoices"
        :filter-by="filterRelatedResourcesOptions"
        v-model="resource[name]"
        :disabled="shouldBeDisabled"
        :placeholder="!relatedResourcesLoaded ? $__('Loading...') : ''"
        @update:modelValue="
            onSelected && onSelected($event, relatedResourcesOptions, resource)
        "
    >
        <template v-slot:option="relatedResource">
            {{ relatedResource[relationshipOptionLabelAttr] }}
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
import { computed, onBeforeMount, ref, watch } from "vue";
export default {
    props: {
        relationshipOptionLabelAttr: String | null,
        relationshipAPIClient: Object | null,
        resource: Object | null,
        name: String | null,
        allowMultipleChoices: Boolean | null,
        relationshipRequiredKey: String | null,
        disabled: Boolean | false,
        required: Boolean | false,
        onSelected: Function | null,
        query: {
            type: Object,
            default: {},
        },
    },
    setup(props) {
        const relatedResources = ref(null);
        const relatedResourcesLoaded = ref(false);
        const queryParameters = ref(props.query);

        onBeforeMount(() => {
            const relatedResourcesClient = props.relationshipAPIClient;
            relatedResourcesClient.getAll(queryParameters.value).then(
                result => {
                    relatedResources.value = result;
                    relatedResourcesLoaded.value = true;
                },
                error => {}
            );
        });
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

        watch(
            () => queryParameters.value,
            () => {
                relatedResources.value = null;
                relatedResourcesLoaded.value = false;
                const relatedResourcesClient = props.relationshipAPIClient;
                relatedResourcesClient.getAll(queryParameters.value).then(
                    result => {
                        relatedResources.value = result;
                        relatedResourcesLoaded.value = true;
                    },
                    error => {}
                );
            }
        );

        return {
            relatedResources,
            relatedResourcesLoaded,
            relatedResourcesOptions,
            shouldBeDisabled,
            filterRelatedResourcesOptions,
            queryParameters,
        };
    },
};
</script>
