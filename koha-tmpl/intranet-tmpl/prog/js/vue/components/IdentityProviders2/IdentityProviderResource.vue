<template>
    <BaseResource :routeAction="routeAction" :instancedResource="this" />
</template>

<script>
import { inject } from "vue";
import BaseResource from "@koha-vue/components/BaseResource.vue";
import { useBaseResource } from "@koha-vue/composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "IdentityProviderResource",
    components: {
        BaseResource,
    },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const getBorrowerColumns = () => window.borrower_columns || [];
        const borrowerColumnsArray = getBorrowerColumns();
        const getLibraries = () => window.libraries_map || [];
        const getCategories = () => window.categories_map || [];

        const resourceAttrs = [
            {
                name: "identity_provider_id",
                type: "number",
                label: __("ID"),
                hideIn: ["List", "Show", "Form"],
            },
            {
                name: "code",
                required: true,
                type: "text",
                label: __("Code"),
                group: "IdP Connection Settings",
            },
            {
                name: "description",
                type: "text",
                label: __("Description"),
                group: "IdP Connection Settings",
            },
            {
                name: "protocol",
                type: "select",
                required: true,
                label: __("Type"),
                group: "IdP Connection Settings",
                options: [
                    { value: "OAuth", description: "OAuth" },
                    { value: "OIDC", description: "OIDC" },
                    { value: "SAML2", description: "SAML2 / Shibboleth" },
                    { value: "CAS", description: "CAS" },
                ],
                requiredKey: "value",
                selectLabel: "description",
            },
            {
                name: "icon_url",
                type: "text",
                label: __("Icon URL"),
                group: "IdP Connection Settings",
            },
            {
                name: "enabled",
                type: "boolean",
                label: __("Enabled"),
                group: "IdP Connection Settings",
            },
            {
                name: "hostnames",
                type: "component",
                componentPath: "IdentityProviders/ProviderHostnames.vue",
                label: __("Hostnames"),
                group: "Network & Entry Settings",
                hideIn: ["List"],
                groupMeta: { requiresId: true },
                componentProps: resource => ({
                    providerId: resource.identity_provider_id,
                }),
            },
            {
                name: "mappings",
                type: "relationshipWidget",
                label: __("Attribute mappings"),
                group: "Attribute Mappings",
                hideIn: ["List"],
                componentProps: {
                    resourceRelationships: {
                        resourceProperty: "mappings",
                    },
                    relationshipI18n: {
                        nameUpperCase: __("Attribute mapping"),
                        removeThisMessage: __("Remove this mapping"),
                        addNewMessage: __("Add new mapping"),
                        noneCreatedYetMessage: __(
                            "There are no mappings created yet"
                        ),
                    },
                    newRelationshipDefaultAttrs: {
                        type: "object",
                        value: {
                            provider_field: null,
                            koha_field: borrowerColumnsArray[0]?.value || null,
                            default_content: null,
                            is_matchpoint: false,
                        },
                    },
                },
                relationshipFields: [
                    {
                        name: "provider_field",
                        type: "text",
                        label: __("IdP field"),
                    },
                    {
                        name: "koha_field",
                        type: "select",
                        label: __("Koha field"),
                        options: borrowerColumnsArray,
                        requiredKey: "value",
                        selectLabel: "label",
                    },
                    {
                        name: "is_matchpoint",
                        type: "boolean",
                        label: __("Matchpoint"),
                    },
                    {
                        name: "default_content",
                        type: "text",
                        label: __("Default value"),
                    },
                ],
            },
            {
                name: "domains",
                type: "relationshipWidget",
                label: __("Domain rules"),
                group: "Domain Logic Handling",
                hideIn: ["List"],
                componentProps: {
                    resourceRelationships: {
                        resourceProperty: "domains",
                    },
                    relationshipI18n: {
                        nameUpperCase: __("Domain rule"),
                        removeThisMessage: __("Remove this domain rule"),
                        addNewMessage: __("Add new domain rule"),
                        noneCreatedYetMessage: __(
                            "There are no domain rules created yet"
                        ),
                    },
                    newRelationshipDefaultAttrs: {
                        type: "object",
                        value: {
                            domain: "",
                            allow_opac: true,
                            allow_staff: false,
                            auto_register_opac: false,
                            auto_register_staff: false,
                            update_on_auth: false,
                            default_library_id: null,
                            default_category_id: null,
                        },
                    },
                },
                relationshipFields: [
                    {
                        name: "domain",
                        type: "text",
                        label: __("Domain pattern"),
                    },
                    {
                        name: "allow_opac",
                        type: "boolean",
                        label: __("Allow OPAC login"),
                    },
                    {
                        name: "allow_staff",
                        type: "boolean",
                        label: __("Allow staff login"),
                    },
                    {
                        name: "auto_register_opac",
                        type: "boolean",
                        label: __("Auto-register (OPAC)"),
                    },
                    {
                        name: "auto_register_staff",
                        type: "boolean",
                        label: __("Auto-register (staff)"),
                    },
                    {
                        name: "default_library_id",
                        type: "select",
                        label: __("Default library"),
                        options: getLibraries(),
                        requiredKey: "value",
                        selectLabel: "label",
                    },
                    {
                        name: "default_category_id",
                        type: "select",
                        label: __("Default category"),
                        options: getCategories(),
                        requiredKey: "value",
                        selectLabel: "label",
                    },
                ],
            },
        ];

        const onFormSave = async (e, resourceToSave) => {
            e.preventDefault();

            const resource = JSON.parse(JSON.stringify(resourceToSave));
            const resourceId = resource.identity_provider_id;

            delete resource.identity_provider_id;
            delete resource.hostnames;
            // Clean up mappings and domains IDs if they are being saved as part of the main resource
            // Note: The API might expect them to be saved separately depending on the implementation.
            // If they are embedded and the API supports it, we keep them but remove their individual IDs for creation.
            if (resource.mappings) {
                resource.mappings = resource.mappings.map(
                    ({ mapping_id, ...rest }) => rest
                );
            }
            if (resource.domains) {
                resource.domains = resource.domains.map(
                    ({ identity_provider_domain_id, ...rest }) => rest
                );
            }

            const client = APIClient.identity_providers.providers;

            try {
                if (resourceId) {
                    const updated = await client.update(resource, resourceId);
                    baseResource.setMessage(__("Identity provider updated"));
                    return updated;
                } else {
                    const newResource = await client.create(resource);
                    baseResource.setMessage(__("Identity provider created"));
                    return newResource; // Return for navigation
                }
            } catch (error) {
                // The httpClient usually surfaces errors
            }
        };

        const onShowSectionSave = async (
            sectionName,
            updatedResource,
            currentResource,
            isNew
        ) => {
            const merged = { ...currentResource, ...updatedResource };
            const resourceId = merged.identity_provider_id;

            const toSave = { ...merged };
            delete toSave.identity_provider_id;
            delete toSave.hostnames; // managed by ProviderHostnames independently
            if (toSave.mappings) {
                toSave.mappings = toSave.mappings.map(
                    ({ mapping_id, ...rest }) => rest
                );
            }
            if (toSave.domains) {
                toSave.domains = toSave.domains.map(
                    ({ identity_provider_domain_id, ...rest }) => rest
                );
            }

            const client = APIClient.identity_providers.providers;

            try {
                if (resourceId) {
                    await client.update(toSave, resourceId);
                    baseResource.setMessage(__("Identity provider updated"));
                    return merged;
                } else {
                    const created = await client.create(toSave);
                    baseResource.setMessage(__("Identity provider created"));
                    return created;
                }
            } catch (error) {
                // errors are surfaced by the httpClient
            }
        };

        const baseResource = useBaseResource({
            resourceName: "identity_provider",
            nameAttr: "description",
            idAttr: "identity_provider_id",
            components: {
                show: "IdentityProviders2Show",
                list: "IdentityProviders2List",
                add: "IdentityProviders2New",
                edit: "IdentityProviders2FormAddEdit",
            },
            apiClient: APIClient.identity_providers.providers,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this identity provider?"
                ),
                deleteSuccessMessage: $__("Identity provider %s deleted"),
                displayName: $__("Identity Provider"),
                editLabel: $__("Edit identity provider #%s"),
                emptyListMessage: $__(
                    "There are no identity providers defined"
                ),
                newLabel: $__("New identity provider"),
            },
            table: {
                resourceTableUrl:
                    APIClient.identity_providers.httpClient._baseURL,
                options: { embed: "hostnames,mappings,domains" },
            },
            formGroupsDisplayMode: "sections",
            showGroupsDisplayMode: "sections",
            resourceAttrs,
            onFormSave,
            onShowSectionSave,
            props,
            moduleStore: "mainStore", // Assuming a generic store for now
        });

        const tableOptions = {
            url: baseResource.getResourceTableUrl(),
            options: { embed: "hostnames,mappings,domains" },
            actions: {
                0: ["show"],
                "-1": ["edit", "delete"],
            },
        };

        return {
            ...baseResource,
            tableOptions,
        };
    },
};
</script>
