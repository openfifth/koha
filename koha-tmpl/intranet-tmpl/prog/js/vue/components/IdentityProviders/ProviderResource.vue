<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <BaseResource v-else :routeAction="routeAction" :instancedResource="this" />
</template>

<script>
import { inject, ref, onMounted, computed } from "vue";
import BaseResource from "./../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

const PROTOCOL_CONFIG_FIELDS = {
    OAuth: [
        {
            name: "key",
            label: __("Client ID"),
            required: true,
            type: "text",
            group: "OAuth credentials",
        },
        {
            name: "secret",
            label: __("Client secret"),
            required: true,
            type: "text",
            group: "OAuth credentials",
        },
        {
            name: "authorize_url",
            label: __("Authorization URL"),
            required: true,
            type: "text",
            group: "OAuth endpoints",
        },
        {
            name: "token_url",
            label: __("Token URL"),
            required: true,
            type: "text",
            group: "OAuth endpoints",
        },
        {
            name: "userinfo_url",
            label: __("User info URL"),
            required: false,
            type: "text",
            group: "OAuth endpoints",
        },
        {
            name: "scope",
            label: __("Scope"),
            required: false,
            type: "text",
            group: "OAuth endpoints",
            toolTip: __("Space-separated list of scopes, e.g. 'email profile'"),
        },
    ],
    OIDC: [
        {
            name: "key",
            label: __("Client ID"),
            required: true,
            type: "text",
            group: "OIDC credentials",
        },
        {
            name: "secret",
            label: __("Client secret"),
            required: true,
            type: "text",
            group: "OIDC credentials",
        },
        {
            name: "well_known_url",
            label: __("Well-known URL"),
            required: true,
            type: "text",
            group: "OIDC endpoints",
            toolTip: __(
                "OpenID Connect discovery endpoint, e.g. https://login.example.com/.well-known/openid-configuration"
            ),
        },
        {
            name: "scope",
            label: __("Scope"),
            required: false,
            type: "text",
            group: "OIDC endpoints",
            toolTip: __(
                "Space-separated list of scopes, e.g. 'openid email profile'"
            ),
        },
    ],
    SAML2: [
        {
            name: "autocreate",
            label: __("Auto-create patrons"),
            required: false,
            type: "boolean",
            group: "User management",
            toolTip: __(
                "Automatically create a patron record for new Shibboleth users"
            ),
        },
        {
            name: "sync",
            label: __("Sync attributes on login"),
            required: false,
            type: "boolean",
            group: "User management",
            toolTip: __("Update patron attributes from the IdP on each login"),
        },
        {
            name: "welcome",
            label: __("Send welcome email"),
            required: false,
            type: "boolean",
            group: "User management",
            toolTip: __("Send a welcome email to newly auto-created patrons"),
        },
    ],
    CAS: [
        {
            name: "server_url",
            label: __("CAS server URL"),
            required: true,
            type: "text",
            group: "CAS settings",
        },
        {
            name: "login_url",
            label: __("Login URL"),
            required: false,
            type: "text",
            group: "CAS settings",
        },
        {
            name: "validate_url",
            label: __("Validate URL"),
            required: false,
            type: "text",
            group: "CAS settings",
        },
    ],
};

export default {
    name: "ProviderResource",
    components: { BaseResource },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const initialized = ref(false);

        const resourceAttrs = [
            {
                name: "code",
                required: true,
                type: "text",
                label: __("Code"),
                group: "Basic configuration",
                toolTip: __(
                    "Unique identifier for this provider. Alphanumeric and underscore only."
                ),
            },
            {
                name: "description",
                required: true,
                type: "text",
                label: __("Description"),
                group: "Basic configuration",
                toolTip: __("User-friendly name displayed on login pages"),
            },
            {
                name: "protocol",
                required: true,
                type: "select",
                label: __("Protocol"),
                group: "Basic configuration",
                options: [
                    { value: "OAuth", label: "OAuth" },
                    { value: "OIDC", label: "OIDC" },
                    { value: "SAML2", label: "SAML2 / Shibboleth" },
                    { value: "CAS", label: "CAS" },
                ],
                requiredKey: "value",
                selectLabel: "label",
            },
            {
                name: "icon_url",
                type: "text",
                label: __("Icon URL"),
                group: "Basic configuration",
                toolTip: __(
                    "URL to an icon image shown on the OPAC login button"
                ),
            },
            {
                name: "enabled",
                type: "boolean",
                label: __("Enabled"),
                group: "Basic configuration",
                toolTip: __(
                    "When disabled, this provider will not be shown on login pages"
                ),
            },
            {
                name: "force_sso_opac",
                type: "boolean",
                label: __("Force SSO (OPAC)"),
                group: "SSO settings",
                toolTip: __(
                    "Automatically redirect OPAC users to this provider's login page"
                ),
            },
            {
                name: "force_sso_staff",
                type: "boolean",
                label: __("Force SSO (staff interface)"),
                group: "SSO settings",
                toolTip: __(
                    "Automatically redirect staff interface users to this provider's login page"
                ),
            },
        ];

        const baseResource = useBaseResource({
            resourceName: "provider",
            nameAttr: "code",
            idAttr: "identity_provider_id",
            components: {
                show: "ProviderShow",
                list: "ProvidersList",
                add: "ProviderFormAdd",
                edit: "ProviderFormEdit",
            },
            apiClient: APIClient.identity_providers.providers,
            i18n: {
                deleteConfirmationMessage: $__(
                    "Are you sure you want to delete this identity provider? All related domain and mapping configuration will also be deleted."
                ),
                deleteSuccessMessage: $__("Identity provider deleted"),
                displayName: $__("Identity provider"),
                editLabel: $__("Edit identity provider"),
                emptyListMessage: $__(
                    "There are no identity providers configured"
                ),
                newLabel: $__("New identity provider"),
            },
            table: {
                resourceTableUrl: "/api/v1/auth/identity_providers",
                options: {},
            },
            stickyToolbar: ["Form"],
            embedded: props.embedded,
            formGroupsDisplayMode: "accordion",
            resourceAttrs,
            props,
            moduleStore: "IdentityProvidersStore",
        });

        onMounted(() => {
            initialized.value = true;
        });

        const onFormSave = (e, providerToSave) => {
            e.preventDefault();
            const provider = JSON.parse(JSON.stringify(providerToSave));
            const providerId = provider.identity_provider_id;

            delete provider.identity_provider_id;

            if (providerId) {
                return baseResource.apiClient.update(provider, providerId).then(
                    updatedProvider => {
                        baseResource.setMessage(
                            $__("Identity provider updated")
                        );
                        return updatedProvider;
                    },
                    error => {}
                );
            } else {
                return baseResource.apiClient.create(provider).then(
                    newProvider => {
                        baseResource.setMessage(
                            $__("Identity provider created")
                        );
                        return newProvider;
                    },
                    error => {}
                );
            }
        };

        return {
            ...baseResource,
            initialized,
            PROTOCOL_CONFIG_FIELDS,
            onFormSave,
        };
    },
};
</script>
