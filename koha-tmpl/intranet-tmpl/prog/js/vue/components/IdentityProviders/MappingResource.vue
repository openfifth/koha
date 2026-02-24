<template>
    <div>
        <BaseResource :routeAction="routeAction" :instancedResource="this" />
    </div>
</template>

<script>
import { ref, onMounted, computed } from "vue";
import { useRoute } from "vue-router";
import BaseResource from "./../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "MappingResource",
    components: { BaseResource },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const route = useRoute();
        const providerId = computed(() => route.params.identity_provider_id);

        const getBorrowerColumns = () => window.borrower_columns || [];
        const borrowerColumnsArray = [
            ...getBorrowerColumns(),
            ...(window.all_patron_attributes || []),
        ];

        const resourceAttrs = [
            {
                name: "koha_field",
                required: true,
                type: "select",
                options: borrowerColumnsArray,
                requiredKey: "value",
                selectLabel: "label",
                label: __("Koha field"),
                group: "Mapping",
                toolTip: __(
                    "The field in the Koha borrowers table to populate, or a patron attribute"
                ),
            },
            {
                name: "provider_field",
                type: "text",
                label: __("Provider attribute"),
                group: "Mapping",
                toolTip: __(
                    "The attribute name supplied by the identity provider. Leave empty to use only the default value."
                ),
            },
            {
                name: "default_content",
                type: "text",
                label: __("Default value"),
                group: "Mapping",
                toolTip: __(
                    "Value to use when the provider does not supply this attribute"
                ),
            },
            {
                name: "sync_on_creation",
                type: "checkbox",
                label: __("Sync on creation"),
                group: "Mapping",
                toolTip: __(
                    "If checked, this field will be synced when the user is first created"
                ),
                default: true,
            },
            {
                name: "sync_on_update",
                type: "checkbox",
                label: __("Sync on update"),
                group: "Mapping",
                toolTip: __(
                    "If checked, this field will be synced on subsequent logins"
                ),
                default: true,
            },
        ];

        const baseResource = useBaseResource({
            resourceName: "mapping",
            nameAttr: "koha_field",
            idAttr: "mapping_id",
            components: {
                show: "MappingShow",
                list: "MappingsList",
                add: "MappingsFormAdd",
                edit: "MappingsFormEdit",
            },
            apiClient: {
                getAll: params =>
                    APIClient.identity_providers.mappings.getAll(
                        providerId.value,
                        params
                    ),
                get: id =>
                    APIClient.identity_providers.mappings.get(
                        providerId.value,
                        id
                    ),
                create: mapping =>
                    APIClient.identity_providers.mappings.create(
                        providerId.value,
                        mapping
                    ),
                update: (m, id) =>
                    APIClient.identity_providers.mappings.update(
                        providerId.value,
                        m,
                        id
                    ),
                delete: id =>
                    APIClient.identity_providers.mappings.delete(
                        providerId.value,
                        id
                    ),
                count: q =>
                    APIClient.identity_providers.mappings.count(
                        providerId.value,
                        q
                    ),
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this field mapping?"
                ),
                deleteSuccessMessage: $__("Mapping deleted"),
                displayName: $__("Field mapping"),
                editLabel: $__("Edit field mapping"),
                emptyListMessage: $__(
                    "There are no field mappings defined for this provider"
                ),
                newLabel: $__("New field mapping"),
            },
            table: {
                resourceTableUrl: `/api/v1/auth/identity_providers/${providerId.value}/mappings`,
                options: {},
            },
            stickyToolbar: ["Form"],
            embedded: props.embedded,
            formGroupsDisplayMode: "accordion",
            resourceAttrs,
            props,
            moduleStore: "IdentityProvidersStore",
        });

        const getResourceShowURL = id =>
            baseResource.router.resolve({
                name: "MappingShow",
                params: {
                    identity_provider_id: providerId.value,
                    identity_provider_mapping_id: id,
                },
            }).href;

        const goToResourceAdd = () =>
            baseResource.router.push({
                name: "MappingsFormAdd",
                params: { identity_provider_id: providerId.value },
            });

        const goToResourceEdit = resource =>
            baseResource.router.push({
                name: "MappingsFormEdit",
                params: {
                    identity_provider_id: providerId.value,
                    identity_provider_mapping_id: resource.mapping_id,
                },
            });

        const goToResourceList = () =>
            baseResource.router.push({
                name: "ProviderShow",
                params: { identity_provider_id: providerId.value },
            });

        // A failed save rejects and propagates to ResourceFormSave, which
        // surfaces the error and skips its own navigation. Unlike
        // ProviderResource we navigate explicitly here: mappings are a
        // sub-resource with no standalone show page, so on success we return
        // to the parent provider.
        const onFormSave = async (e, mappingToSave) => {
            e.preventDefault();

            const mapping = JSON.parse(JSON.stringify(mappingToSave));
            const mapping_id = mapping.mapping_id;

            delete mapping.mapping_id;
            delete mapping.identity_provider_id;

            if (mapping_id) {
                await APIClient.identity_providers.mappings.update(
                    providerId.value,
                    mapping,
                    mapping_id
                );
                baseResource.setMessage(__("Mapping updated"));
            } else {
                await APIClient.identity_providers.mappings.create(
                    providerId.value,
                    mapping
                );
                baseResource.setMessage(__("Mapping created"));
            }

            baseResource.router.push({
                name: "ProviderShow",
                params: { identity_provider_id: providerId.value },
            });
        };

        const tableOptions = {
            url: baseResource.getResourceTableUrl(),
            actions: {
                "-1": ["edit", "delete"],
            },
        };

        return {
            ...baseResource,
            getResourceShowURL,
            goToResourceAdd,
            goToResourceEdit,
            goToResourceList,
            tableOptions,
            onFormSave,
        };
    },
};
</script>
