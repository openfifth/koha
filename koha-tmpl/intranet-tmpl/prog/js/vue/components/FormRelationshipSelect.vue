<template>
    <v-select
        :getOptionLabel="
            relatedResource => relatedResource[relationshipOptionLabelAttr]
        "
        :id="name"
        :reduce="relatedResource => relatedResource[relationshipRequiredKey]"
        :options="relatedResourcesOptions"
        :required="isRequired"
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
    setup(props, { emit }) {
        const relatedResources = ref(null);
        const relatedResourcesLoaded = ref(false);
        const queryParameters = ref(props.query);

        onBeforeMount(() => {
            const relatedResourcesClient = props.relationshipAPIClient;
            relatedResourcesClient.getAll(queryParameters.value).then(
                result => {
                    relatedResources.value = result;
                    relatedResourcesLoaded.value = true;
                    emit("resourcesLoaded", props.resource[props.name], result);
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

        const isRequired = computed(() => {
            const valueDefined = Array.isArray(props.resource[props.name])
                ? !!props.resource[props.name].length
                : props.resource[props.name];
            return props.required && !valueDefined;
        });

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
            isRequired,
        };
    },
    emits: ["resourcesLoaded"],
};
</script>
