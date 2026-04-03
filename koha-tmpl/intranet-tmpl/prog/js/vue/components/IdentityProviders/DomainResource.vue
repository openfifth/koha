<template>
    <div>
        <BaseResource :routeAction="routeAction" :instancedResource="this" />
    </div>
</template>

<script>
import { ref, computed } from "vue";
import { useRoute } from "vue-router";
import BaseResource from "./../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "DomainResource",
    components: { BaseResource },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const route = useRoute();
        const providerId = computed(() => route.params.identity_provider_id);

        const getLibraries = () => window.libraries_map || [];
        const getCategories = () => window.categories_map || [];

        const resourceAttrs = [
            {
                name: "domain",
                type: "text",
                label: __("Domain"),
                group: "Domain",
                toolTip: __(
                    "Email domain to match. Use '*' or leave empty for any domain. Wildcards like '*library.com' are supported."
                ),
            },
            {
                name: "allow_opac",
                type: "boolean",
                label: __("Allow OPAC login"),
                group: "Access",
                toolTip: __("Allow users of this domain to log into the OPAC"),
            },
            {
                name: "allow_staff",
                type: "boolean",
                label: __("Allow staff login"),
                group: "Access",
                toolTip: __(
                    "Allow users of this domain to log into the staff interface"
                ),
            },
            {
                name: "auto_register_opac",
                type: "boolean",
                label: __("Auto-register (OPAC)"),
                group: "Auto-registration",
                toolTip: __(
                    "Automatically create patron records for new OPAC users from this domain"
                ),
            },
            {
                name: "auto_register_staff",
                type: "boolean",
                label: __("Auto-register (staff)"),
                group: "Auto-registration",
                toolTip: __(
                    "Automatically create patron records for new staff users from this domain"
                ),
            },
            {
                name: "update_on_auth",
                type: "boolean",
                label: __("Update patron data on login"),
                group: "Auto-registration",
                toolTip: __(
                    "Sync patron attributes from the provider on each login"
                ),
            },
            {
                name: "default_library_id",
                type: "select",
                label: __("Default library"),
                group: "Auto-registration defaults",
                options: getLibraries(),
                requiredKey: "value",
                selectLabel: "label",
                toolTip: __("Library assigned to auto-registered patrons"),
            },
            {
                name: "default_category_id",
                type: "select",
                label: __("Default category"),
                group: "Auto-registration defaults",
                options: getCategories(),
                requiredKey: "value",
                selectLabel: "label",
                toolTip: __(
                    "Patron category assigned to auto-registered patrons"
                ),
            },
        ];

        const baseResource = useBaseResource({
            resourceName: "domain",
            nameAttr: "domain",
            idAttr: "identity_provider_domain_id",
            components: {
                show: "DomainShow",
                list: "DomainsList",
                add: "DomainsFormAdd",
                edit: "DomainsFormEdit",
            },
            apiClient: {
                getAll: params =>
                    APIClient.identity_providers.domains.getAll(
                        providerId.value,
                        params
                    ),
                get: id =>
                    APIClient.identity_providers.domains.get(
                        providerId.value,
                        id
                    ),
                create: domain =>
                    APIClient.identity_providers.domains.create(
                        providerId.value,
                        domain
                    ),
                update: (d, id) =>
                    APIClient.identity_providers.domains.update(
                        providerId.value,
                        d,
                        id
                    ),
                delete: id =>
                    APIClient.identity_providers.domains.delete(
                        providerId.value,
                        id
                    ),
                count: (query = {}) =>
                    APIClient.identity_providers.domains.count(
                        providerId.value,
                        query
                    ),
            },
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to remove this domain configuration?"
                ),
                deleteSuccessMessage: $__("Domain deleted"),
                displayName: $__("Domain"),
                editLabel: $__("Edit domain"),
                emptyListMessage: $__(
                    "There are no domains configured for this provider"
                ),
                newLabel: $__("New domain"),
            },
            table: {
                resourceTableUrl: `/api/v1/auth/identity_providers/${providerId.value}/domains`,
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
                name: "DomainShow",
                params: {
                    identity_provider_id: providerId.value,
                    identity_provider_domain_id: id,
                },
            }).href;

        const goToResourceAdd = () =>
            baseResource.router.push({
                name: "DomainsFormAdd",
                params: { identity_provider_id: providerId.value },
            });

        const goToResourceEdit = resource =>
            baseResource.router.push({
                name: "DomainsFormEdit",
                params: {
                    identity_provider_id: providerId.value,
                    identity_provider_domain_id:
                        resource.identity_provider_domain_id,
                },
            });

        const goToResourceList = () =>
            baseResource.router.push({
                name: "ProviderShow",
                params: { identity_provider_id: providerId.value },
            });

        const onFormSave = (e, domainToSave) => {
            e.preventDefault();
            const domain = JSON.parse(JSON.stringify(domainToSave));
            const domainId = domain.identity_provider_domain_id;

            delete domain.identity_provider_domain_id;
            delete domain.identity_provider_id;

            if (domainId) {
                return baseResource.apiClient.update(domain, domainId).then(
                    updatedDomain => {
                        baseResource.setMessage($__("Domain updated"));
                        baseResource.router.push({
                            name: "ProviderShow",
                            params: {
                                identity_provider_id: providerId.value,
                            },
                        });
                        return updatedDomain;
                    },
                    error => {}
                );
            } else {
                return baseResource.apiClient.create(domain).then(
                    newDomain => {
                        baseResource.setMessage($__("Domain created"));
                        baseResource.router.push({
                            name: "ProviderShow",
                            params: {
                                identity_provider_id: providerId.value,
                            },
                        });
                        return newDomain;
                    },
                    error => {}
                );
            }
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
