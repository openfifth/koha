<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <template v-else-if="routeAction === 'show'">
        <TabsWrapper
            :tabList="[
                { name: $__('Details') },
                { name: $__('Field mappings') },
                { name: $__('Domains') },
            ]"
        >
            <template #tabContent="{ tabGroup }">
                <BaseResource
                    v-if="tabGroup.name === $__('Details')"
                    routeAction="show"
                    :instancedResource="this"
                />
                <MappingResource
                    v-else-if="tabGroup.name === $__('Field mappings')"
                    routeAction="list"
                />
                <DomainResource v-else routeAction="list" />
            </template>
        </TabsWrapper>
    </template>
    <BaseResource v-else :routeAction="routeAction" :instancedResource="this" />
</template>

<script>
import { ref, onMounted, reactive, watch } from "vue";
import BaseResource from "./../BaseResource.vue";
import TabsWrapper from "./../TabsWrapper.vue";
import MappingResource from "./MappingResource.vue";
import DomainResource from "./DomainResource.vue";
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
    components: { BaseResource, TabsWrapper, MappingResource, DomainResource },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const initialized = ref(false);

        // Tracks the currently selected/loaded protocol so config field groups
        // can be shown or hidden reactively via hideIn closures.
        const selectedProtocol = ref(null);

        const staticResourceAttrs = [
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

        // Build config attrs for ALL protocols. Each gets a hideIn closure that
        // hides it when a different protocol is selected. When no protocol is
        // selected yet (add mode), all groups remain visible so the user can
        // see what fields are available after choosing a protocol.
        const configResourceAttrs = Object.entries(
            PROTOCOL_CONFIG_FIELDS
        ).flatMap(([protocol, fields]) =>
            fields.map(f => ({
                ...f,
                name: `_config_${f.name}`,
                hideIn: () =>
                    selectedProtocol.value &&
                    selectedProtocol.value !== protocol
                        ? ["Form", "Show", "List"]
                        : ["List"],
            }))
        );

        const resourceAttrs = [...staticResourceAttrs, ...configResourceAttrs];

        // Unpack the JSON config blob into flat _config_* fields so the form
        // and show views can bind to them individually.
        const afterResourceFetch = (componentData, resource) => {
            selectedProtocol.value = resource.protocol || null;
            const config = resource.config || {};
            const fields = PROTOCOL_CONFIG_FIELDS[resource.protocol] || [];
            fields.forEach(field => {
                resource[`_config_${field.name}`] =
                    field.type === "boolean"
                        ? (config[field.name] ?? false)
                        : (config[field.name] ?? "");
            });
        };

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
            afterResourceFetch,
            props,
            moduleStore: "IdentityProvidersStore",
        });

        const tableOptions = {
            url: baseResource.getResourceTableUrl(),
            actions: {
                "-1": ["delete"],
            },
        };

        // In add mode the form uses reactive(newResource) as its data object.
        // reactive() uses a WeakMap so calling it with the same plain object
        // returns the same proxy. Watching here therefore sees the same
        // mutations that ResourceFormSave makes when the user changes the
        // protocol dropdown.
        const formStateObj = reactive(baseResource.newResource.value);
        watch(
            () => formStateObj.protocol,
            newProtocol => {
                selectedProtocol.value = newProtocol || null;
            }
        );

        onMounted(() => {
            initialized.value = true;
        });

        const onFormSave = (e, providerToSave) => {
            e.preventDefault();
            const provider = JSON.parse(JSON.stringify(providerToSave));
            const providerId = provider.identity_provider_id;
            const protocol = provider.protocol;

            // Collect the _config_* fields for the selected protocol into a
            // config object, then strip all _config_* keys from the payload.
            const configFieldDefs = PROTOCOL_CONFIG_FIELDS[protocol] || [];
            const config = {};
            configFieldDefs.forEach(field => {
                const flatKey = `_config_${field.name}`;
                if (flatKey in provider) {
                    config[field.name] = provider[flatKey];
                }
            });
            Object.keys(provider)
                .filter(k => k.startsWith("_config_"))
                .forEach(k => delete provider[k]);
            provider.config = config;

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
            tableOptions,
            onFormSave,
        };
    },
};
</script>
