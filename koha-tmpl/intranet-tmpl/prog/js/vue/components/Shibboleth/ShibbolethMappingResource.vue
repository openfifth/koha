<template>
    <div>
        <div
            v-if="routeAction === 'list' && showAutocreateWarning"
            class="alert alert-info"
        >
            <i class="fa fa-info-circle"></i>
            {{
                $__(
                    "When autocreate is enabled, field mappings for 'branchcode' and 'categorycode' are required. These can use either IdP attributes or default values."
                )
            }}
        </div>
        <BaseResource :routeAction="routeAction" :instancedResource="this" />
    </div>
</template>

<script>
import { inject, computed, onMounted, ref } from "vue";
import BaseResource from "./../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";
import { useShibbolethStore } from "../../stores/shibboleth.js";

export default {
    name: "ShibbolethMappingResource",
    components: {
        BaseResource,
    },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const getBorrowerColumns = () => {
            return window.borrower_columns || [];
        };

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
                group: "Details",
                toolTip: __("The field name in the Koha borrowers table"),
            },
            {
                name: "idp_field",
                type: "text",
                label: __("Identity Provider attribute"),
                group: "Details",
                toolTip: __(
                    "The attribute name provided by the Shibboleth Identity Provider"
                ),
            },
            {
                name: "default_content",
                type: "text",
                label: __("Default value"),
                group: "Details",
                toolTip: __(
                    "Default value to use if the IdP doesn't provide this attribute"
                ),
            },
            {
                name: "is_matchpoint",
                type: "boolean",
                label: __("Use as matchpoint"),
                group: "Details",
                toolTip: __(
                    "Use this field to match existing users (only one matchpoint allowed)"
                ),
            },
        ];

        const baseResource = useBaseResource({
            resourceName: "mapping",
            nameAttr: "koha_field",
            idAttr: "mapping_id",
            components: {
                show: "ShibbolethMappingsShow",
                list: "ShibbolethMappingsList",
                add: "ShibbolethMappingsFormAdd",
                edit: "ShibbolethMappingsFormEdit",
            },
            apiClient: APIClient.shibboleth.mappings,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this field mapping?"
                ),
                deleteSuccessMessage: $__("Mapping deleted"),
                displayName: $__("Field Mapping"),
                editLabel: $__("Edit field mapping"),
                emptyListMessage: $__("There are no field mappings defined"),
                newLabel: $__("New field mapping"),
            },
            table: {
                resourceTableUrl:
                    APIClient.shibboleth.httpClient._baseURL + "mappings",
                options: {},
            },
            stickyToolbar: ["Form"],
            embedded: props.embedded,
            formGroupsDisplayMode: "accordion",
            resourceAttrs,
            props,
            moduleStore: "ShibbolethStore",
        });

        const tableOptions = {
            url: () => baseResource.getResourceTableUrl(),
            options: {},
            table_settings: null,
            actions: {
                0: ["show"],
                "-1": ["edit", "delete"],
            },
        };

        const onFormSave = async (e, mappingToSave) => {
            e.preventDefault();

            const mapping = JSON.parse(JSON.stringify(mappingToSave));
            const mapping_id = mapping.mapping_id;

            delete mapping.mapping_id;

            const client = APIClient.shibboleth.mappings;

            try {
                if (mapping_id) {
                    await client.update(mapping, mapping_id);
                    baseResource.setMessage(__("Mapping updated"));
                } else {
                    await client.create(mapping);
                    baseResource.setMessage(__("Mapping created"));
                }

                baseResource.router.push({ name: "ShibbolethMappingsList" });
            } catch (error) {
                // Errors handled by base resource
            }
        };

        const shibbolethStore = useShibbolethStore();
        const config = ref(null);

        const showAutocreateWarning = computed(() => {
            return config.value?.autocreate === true;
        });

        onMounted(async () => {
            try {
                config.value = await APIClient.shibboleth.config.get();
            } catch (error) {
                console.error("Failed to fetch shibboleth config:", error);
            }
        });

        return {
            ...baseResource,
            tableOptions,
            onFormSave,
            showAutocreateWarning,
        };
    },
};
</script>
