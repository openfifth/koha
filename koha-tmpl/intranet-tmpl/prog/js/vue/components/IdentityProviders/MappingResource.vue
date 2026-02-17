<template>
    <div>
        <BaseResource :routeAction="routeAction" :instancedResource="this" />
    </div>
</template>

<script>
import { ref, onMounted, computed } from "vue";
import BaseResource from "./../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "MappingResource",
    components: { BaseResource },
    props: {
        routeAction: String,
        providerId: {
            type: [String, Number],
            required: true,
        },
    },
    emits: ["select-resource"],
    setup(props) {
        const getBorrowerColumns = () => window.borrower_columns || [];
        const borrowerColumnsArray = getBorrowerColumns();

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
                    "The field in the Koha borrowers table to populate"
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
                name: "is_matchpoint",
                type: "boolean",
                label: __("Use as matchpoint"),
                group: "Mapping",
                toolTip: __(
                    "Match incoming users against this field. Only one mapping per provider may be the matchpoint."
                ),
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
                        props.providerId,
                        params
                    ),
                get: id =>
                    APIClient.identity_providers.mappings.get(
                        props.providerId,
                        id
                    ),
                create: mapping =>
                    APIClient.identity_providers.mappings.create(
                        props.providerId,
                        mapping
                    ),
                update: (m, id) =>
                    APIClient.identity_providers.mappings.update(
                        props.providerId,
                        m,
                        id
                    ),
                delete: id =>
                    APIClient.identity_providers.mappings.delete(
                        props.providerId,
                        id
                    ),
                count: q =>
                    APIClient.identity_providers.mappings.count(
                        props.providerId,
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
                resourceTableUrl: `/api/v1/auth/identity_providers/${props.providerId}/mappings`,
                options: {},
            },
            stickyToolbar: ["Form"],
            embedded: props.embedded,
            formGroupsDisplayMode: "accordion",
            resourceAttrs,
            props,
            moduleStore: "IdentityProvidersStore",
        });

        const onFormSave = async (e, mappingToSave) => {
            e.preventDefault();

            const mapping = JSON.parse(JSON.stringify(mappingToSave));
            const mapping_id = mapping.mapping_id;

            delete mapping.mapping_id;
            delete mapping.identity_provider_id;

            try {
                if (mapping_id) {
                    await APIClient.identity_providers.mappings.update(
                        props.providerId,
                        mapping,
                        mapping_id
                    );
                    baseResource.setMessage(__("Mapping updated"));
                } else {
                    await APIClient.identity_providers.mappings.create(
                        props.providerId,
                        mapping
                    );
                    baseResource.setMessage(__("Mapping created"));
                }

                baseResource.router.push({ name: "MappingsList" });
            } catch (error) {
                // Errors handled by base resource
            }
        };

        return {
            ...baseResource,
            onFormSave,
        };
    },
};
</script>
