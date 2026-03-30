<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <BaseResource v-else :routeAction="routeAction" :instancedResource="this" />
</template>

<script>
import { ref, onMounted, reactive, watch } from "vue";
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
            group: "OAuth settings",
        },
        {
            name: "secret",
            label: __("Client secret"),
            required: true,
            type: "text",
            group: "OAuth settings",
        },
        {
            name: "authorize_url",
            label: __("Authorization URL"),
            required: true,
            type: "text",
            group: "OAuth settings",
        },
        {
            name: "token_url",
            label: __("Token URL"),
            required: true,
            type: "text",
            group: "OAuth settings",
        },
        {
            name: "userinfo_url",
            label: __("User info URL"),
            required: false,
            type: "text",
            group: "OAuth settings",
        },
        {
            name: "scope",
            label: __("Scope"),
            required: false,
            type: "text",
            group: "OAuth settings",
            toolTip: __("Space-separated list of scopes, e.g. 'email profile'"),
        },
    ],
    OIDC: [
        {
            name: "key",
            label: __("Client ID"),
            required: true,
            type: "text",
            group: "OIDC settings",
        },
        {
            name: "secret",
            label: __("Client secret"),
            required: true,
            type: "text",
            group: "OIDC settings",
        },
        {
            name: "well_known_url",
            label: __("Well-known URL"),
            required: true,
            type: "text",
            group: "OIDC settings",
            toolTip: __(
                "OpenID Connect discovery endpoint, e.g. https://login.example.com/.well-known/openid-configuration"
            ),
        },
        {
            name: "scope",
            label: __("Scope"),
            required: false,
            type: "text",
            group: "OIDC settings",
            toolTip: __(
                "Space-separated list of scopes, e.g. 'openid email profile'"
            ),
        },
    ],
    SAML2: [
        {
            name: "saml2_sp_note",
            type: "group_placeholder",
            group: "SAML2 settings",
            description: __(
                "SAML2/Shibboleth connection is handled by the native service provider software (e.g. mod_shib) configured on this server. No Koha-side connection settings are required."
            ),
        },
    ],
};

export default {
    name: "ProviderResource",
    components: {
        BaseResource,
    },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const initialized = ref(false);

        // Tracks the currently selected/loaded protocol so config field groups
        // can be shown or hidden reactively via hideIn closures.
        const selectedProtocol = ref(null);

        // Tracks the IDs of sub-resources that existed when the provider was
        // loaded, so we can delete any that the user removed during editing.
        const originalMappingIds = ref([]);
        const originalHostnameIds = ref([]);
        const originalDomainIds = ref([]);

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
        ];

        const protocolPlaceholderAttr = {
            name: "_protocol_placeholder",
            type: "group_placeholder",
            group: "Protocol settings",
            description: __(
                "Select a protocol above to expose protocol-specific settings"
            ),
            hideIn: () =>
                selectedProtocol.value
                    ? ["Form", "Show", "List"]
                    : ["Show", "List"],
        };

        // Build config attrs for ALL protocols. Each gets a hideIn closure that
        // hides it when a different protocol is selected, or when no protocol
        // has been selected yet (add mode).
        const configResourceAttrs = Object.entries(
            PROTOCOL_CONFIG_FIELDS
        ).flatMap(([protocol, fields]) =>
            fields.map(f => ({
                ...f,
                name: `_config_${f.name}`,
                hideIn: () =>
                    !selectedProtocol.value ||
                    selectedProtocol.value !== protocol
                        ? ["Form", "Show", "List"]
                        : ["List"],
            }))
        );

        const borrowerColumnsArray = (window.borrower_columns || []).map(
            col => ({ value: col.value, label: col.label })
        );

        const matchpointOptions = [
            { value: "cardnumber", label: __("Card number") },
            { value: "userid", label: __("Username") },
            { value: "email", label: __("Email address") },
            ...(window.unique_patron_attributes || []),
        ];
        const librariesArray = (window.libraries_map || []).map(lib => ({
            value: lib.value,
            label: lib.label,
        }));
        const categoriesArray = (window.categories_map || []).map(cat => ({
            value: cat.value,
            label: cat.label,
        }));

        const hostnameAttr = {
            name: "hostnames",
            type: "relationshipWidget",
            group: "Network & Entry Settings",
            hideIn: ["List"],
            showElement: {
                type: "table",
                columnData: "hostnames",
                hidden: provider => !!provider.hostnames?.length,
                columns: [
                    { name: __("Hostname"), value: "hostname" },
                    { name: __("Exclusive provider"), value: "is_exclusive" },
                    { name: __("Matchpoint"), value: "matchpoint" },
                ],
            },
            componentProps: {
                resourceRelationships: { resourceProperty: "hostnames" },
                relationshipI18n: {
                    nameUpperCase: __("Hostname"),
                    removeThisMessage: __("Remove this hostname"),
                    addNewMessage: __("Add hostname"),
                    noneCreatedYetMessage: __(
                        "No hostnames configured. Add a hostname to surface this provider on its login page."
                    ),
                },
                newRelationshipDefaultAttrs: {
                    type: "object",
                    value: {
                        hostname: "",
                        is_exclusive: false,
                        matchpoint: null,
                    },
                },
            },
            relationshipFields: [
                {
                    name: "hostname",
                    required: true,
                    indexRequired: true,
                    type: "select",
                    label: __("Hostname"),
                    placeholder: __("Select or type to add a new hostname..."),
                    options: [],
                    selectLabel: "hostname",
                    requiredKey: "hostname",
                    taggable: true,
                    createOption: h => ({ hostname: h }),
                    toolTip: __(
                        "Base URL used to access this Koha interface, protocol not required. Use '*' to surface this provider on all login pages regardless of hostname."
                    ),
                },
                {
                    name: "is_exclusive",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Exclusive provider"),
                    toolTip: __(
                        "Make this the only login option for this hostname, suppressing all other auth methods"
                    ),
                    badgeTrueLabel: __("Force SSO"),
                    badgeTrueClass: "bg-primary",
                },
                {
                    name: "matchpoint",
                    required: true,
                    indexRequired: true,
                    type: "select",
                    label: __("Matchpoint"),
                    options: matchpointOptions,
                    requiredKey: "value",
                    selectLabel: "label",
                    toolTip: __(
                        "Koha field used to identify existing patrons logging in from this hostname"
                    ),
                },
            ],
        };

        const mappingsAttr = {
            name: "mappings",
            type: "relationshipWidget",
            label: __("Attribute Mappings"),
            group: "Attribute Mappings",
            hideIn: ["List"],
            showElement: {
                type: "table",
                columnData: "mappings",
                hidden: provider => !!provider.mappings?.length,
                columns: [
                    { name: __("Koha field"), value: "koha_field" },
                    { name: __("IdP field"), value: "provider_field" },
                    { name: __("Default value"), value: "default_content" },
                ],
            },
            componentProps: {
                resourceRelationships: { resourceProperty: "mappings" },
                relationshipI18n: {
                    nameUpperCase: __("Mapping"),
                    noneCreatedYetMessage: __("No attribute mappings defined."),
                    addNewMessage: __("Add mapping"),
                    removeThisMessage: __("Remove"),
                },
                newRelationshipDefaultAttrs: {
                    type: "object",
                    value: {
                        provider_field: "",
                        koha_field: borrowerColumnsArray[0]?.value || "",
                        default_content: "",
                    },
                },
            },
            relationshipFields: [
                {
                    name: "koha_field",
                    required: true,
                    indexRequired: true,
                    type: "select",
                    label: __("Koha field"),
                    options: borrowerColumnsArray,
                    requiredKey: "value",
                    selectLabel: "label",
                },
                {
                    name: "provider_field",
                    indexRequired: true,
                    type: "text",
                    label: __("IdP field"),
                    placeholder: __("e.g. given_name"),
                },
                {
                    name: "default_content",
                    indexRequired: true,
                    type: "component",
                    componentPath:
                        "@koha-vue/components/PatronFieldValueInput.vue",
                    componentProps: {
                        resource: { type: "resource" },
                        librariesArray: {
                            type: "object",
                            value: librariesArray,
                        },
                        categoriesArray: {
                            type: "object",
                            value: categoriesArray,
                        },
                    },
                    label: __("Default value"),
                    toolTip: __(
                        "Static value to use for this field when the IdP does not provide one. Only applied when creating a new patron account and only when 'Sync on creation' is enabled. Never used on update. For library and category defaults that vary by email domain, use the 'Default library' and 'Default category' settings on the Email Domain Rule instead."
                    ),
                },
            ],
        };

        const domainsAttr = {
            name: "domains",
            type: "relationshipWidget",
            label: __("Email Domain Rules"),
            group: "Email Domain Rules",
            hideIn: ["List"],
            showElement: {
                type: "table",
                columnData: "domains",
                hidden: provider => !!provider.domains?.length,
                columns: [
                    { name: __("Domain"), value: "domain" },
                    { name: __("Allow OPAC"), value: "allow_opac" },
                    { name: __("Allow staff"), value: "allow_staff" },
                    {
                        name: __("Auto-register (OPAC)"),
                        value: "auto_register_opac",
                    },
                    {
                        name: __("Auto-register (staff)"),
                        value: "auto_register_staff",
                    },
                    { name: __("Update on auth"), value: "update_on_auth" },
                    {
                        name: __("Send welcome email"),
                        value: "send_welcome_email",
                    },
                    {
                        name: __("Default library"),
                        value: "default_library_id",
                    },
                    {
                        name: __("Default category"),
                        value: "default_category_id",
                    },
                ],
            },
            componentProps: {
                resourceRelationships: { resourceProperty: "domains" },
                relationshipI18n: {
                    nameUpperCase: __("Domain"),
                    removeThisMessage: __("Remove this domain"),
                    addNewMessage: __("Add domain rule"),
                    noneCreatedYetMessage: __("No domain rules defined."),
                },
                newRelationshipDefaultAttrs: {
                    type: "object",
                    value: {
                        domain: "",
                        allow_opac: false,
                        allow_staff: false,
                        auto_register_opac: false,
                        auto_register_staff: false,
                        update_on_auth: false,
                        send_welcome_email: false,
                        default_library_id: librariesArray[0]?.value || "",
                        default_category_id: categoriesArray[0]?.value || "",
                    },
                },
            },
            relationshipFields: [
                {
                    name: "domain",
                    type: "text",
                    indexRequired: true,
                    label: __("Domain"),
                    placeholder: __("e.g. library.org or *"),
                    toolTip: __(
                        "Email domain to match. Use '*' or leave empty for any domain."
                    ),
                },
                {
                    name: "allow_opac",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Allow OPAC login"),
                    badgeTrueLabel: __("OPAC"),
                    badgeTrueClass: "bg-success",
                },
                {
                    name: "allow_staff",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Allow staff login"),
                    badgeTrueLabel: __("Staff"),
                    badgeTrueClass: "bg-primary",
                },
                {
                    name: "auto_register_opac",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Auto-register (OPAC)"),
                },
                {
                    name: "auto_register_staff",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Auto-register (staff)"),
                },
                {
                    name: "update_on_auth",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Update patron data on login"),
                },
                {
                    name: "send_welcome_email",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Send welcome email"),
                    toolTip: __(
                        "Send a welcome email to the patron on their first login via this provider"
                    ),
                },
                {
                    name: "default_library_id",
                    type: "select",
                    indexRequired: true,
                    label: __("Default library"),
                    options: librariesArray,
                    requiredKey: "value",
                    selectLabel: "label",
                    toolTip: __(
                        "Home library assigned to new patrons created by auto-registration for this domain rule. Acts as a fallback — any attribute mapping that provides a value for the patron's home library takes precedence. Setting this per domain rule allows patrons from different email domains to be assigned to different libraries automatically."
                    ),
                },
                {
                    name: "default_category_id",
                    type: "select",
                    indexRequired: true,
                    label: __("Default category"),
                    options: categoriesArray,
                    requiredKey: "value",
                    selectLabel: "label",
                    toolTip: __(
                        "Patron category assigned to new patrons created by auto-registration for this domain rule. Acts as a fallback — any attribute mapping that provides a value for the patron category takes precedence. Setting this per domain rule allows patrons from different email domains to be assigned to different categories automatically."
                    ),
                },
            ],
        };

        const resourceAttrs = [
            ...staticResourceAttrs,
            protocolPlaceholderAttr,
            ...configResourceAttrs,
            hostnameAttr,
            mappingsAttr,
            domainsAttr,
        ];

        // Unpack the JSON config blob into flat _config_* fields so the form
        // and show views can bind to them individually.
        const afterResourceFetch = (componentData, resource) => {
            selectedProtocol.value = resource.protocol || null;
            const config = resource.config || {};
            const fields = PROTOCOL_CONFIG_FIELDS[resource.protocol] || [];
            fields.forEach(field => {
                if (field.type === "group_placeholder") return;
                resource[`_config_${field.name}`] =
                    field.type === "boolean"
                        ? (config[field.name] ?? false)
                        : (config[field.name] ?? "");
            });
            if (!resource.domains) resource.domains = [];
            if (!resource.mappings) resource.mappings = [];
            resource.hostnames = resource.hostnames || [];

            // Store the IDs of existing sub-resources so we can delete any
            // that the user removes during an edit.
            originalMappingIds.value = resource.mappings
                .map(m => m.mapping_id)
                .filter(Boolean);
            originalHostnameIds.value = resource.hostnames
                .map(h => h.identity_provider_hostname_id)
                .filter(Boolean);
            originalDomainIds.value = resource.domains
                .map(d => d.identity_provider_domain_id)
                .filter(Boolean);
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
                0: ["show"],
                "-1": ["edit", "delete"],
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

        onMounted(async () => {
            try {
                const data =
                    await APIClient.identity_providers.allHostnames.getAll();
                hostnameAttr.relationshipFields[0].options = data || [];
            } catch (_) {
                // proceed with empty options; user can still type a hostname
            }
            initialized.value = true;
        });

        const onFormSave = async (e, providerToSave) => {
            e.preventDefault();
            const provider = JSON.parse(JSON.stringify(providerToSave));
            const providerId = provider.identity_provider_id;
            const protocol = provider.protocol;

            // Collect the _config_* fields for the selected protocol into a
            // config object, then strip all _config_* keys from the payload.
            const configFieldDefs = PROTOCOL_CONFIG_FIELDS[protocol] || [];
            const config = {};
            configFieldDefs.forEach(field => {
                if (field.type === "group_placeholder") return;
                const flatKey = `_config_${field.name}`;
                if (flatKey in provider) {
                    config[field.name] = provider[flatKey];
                }
            });
            // Strip all _-prefixed keys (UI-only fields: _config_*, _protocol_*, etc.)
            Object.keys(provider)
                .filter(k => k.startsWith("_"))
                .forEach(k => delete provider[k]);
            // matchpoint moved to hostname level; remove from provider payload
            delete provider.matchpoint;
            provider.config = config;

            // Hostnames are managed separately via the hostnames API.
            const hostnamesFromForm = (provider.hostnames || []).filter(
                h => h.hostname
            );
            delete provider.hostnames;

            // Mappings are managed separately via the mappings API.
            // Only items with a koha_field are saved.
            const mappingsFromForm = (provider.mappings || []).filter(
                m => m.koha_field
            );
            delete provider.mappings;

            // Validate that each hostname's matchpoint (if set) has a corresponding mapping.
            for (const h of hostnamesFromForm) {
                const matchpoint = h.matchpoint || null;
                if (matchpoint) {
                    const hasMapping = mappingsFromForm.some(
                        m => m.koha_field === matchpoint
                    );
                    if (!hasMapping) {
                        baseResource.setError(
                            __(
                                "The selected matchpoint must have a corresponding attribute mapping"
                            )
                        );
                        return;
                    }
                }
            }

            // Domains are managed separately via the domains API.
            const domainsFromForm = provider.domains || [];
            delete provider.domains;

            delete provider.identity_provider_id;

            try {
                if (providerId) {
                    const updatedProvider = await baseResource.apiClient.update(
                        provider,
                        providerId
                    );

                    // Sync hostnames: delete removed, update existing, create new.
                    const keptHostnameIds = hostnamesFromForm
                        .map(h => h.identity_provider_hostname_id)
                        .filter(Boolean);
                    for (const id of originalHostnameIds.value.filter(
                        id => !keptHostnameIds.includes(id)
                    )) {
                        await APIClient.identity_providers.hostnames.delete(
                            providerId,
                            id
                        );
                    }
                    for (const h of hostnamesFromForm) {
                        const body = {
                            hostname: h.hostname,
                            is_enabled: h.is_enabled ?? true,
                            is_exclusive: h.is_exclusive ?? false,
                            matchpoint: h.matchpoint || null,
                        };
                        if (h.identity_provider_hostname_id) {
                            await APIClient.identity_providers.hostnames.update(
                                providerId,
                                body,
                                h.identity_provider_hostname_id
                            );
                        } else {
                            await APIClient.identity_providers.hostnames.create(
                                providerId,
                                body
                            );
                        }
                    }

                    // Sync mappings: delete removed, update existing, create new.
                    const keptMappingIds = mappingsFromForm
                        .map(m => m.mapping_id)
                        .filter(Boolean);
                    for (const id of originalMappingIds.value.filter(
                        id => !keptMappingIds.includes(id)
                    )) {
                        await APIClient.identity_providers.mappings.delete(
                            providerId,
                            id
                        );
                    }
                    for (const m of mappingsFromForm) {
                        const body = {
                            provider_field: m.provider_field || null,
                            koha_field: m.koha_field,
                            default_content: m.default_content || null,
                        };
                        if (m.mapping_id) {
                            await APIClient.identity_providers.mappings.update(
                                providerId,
                                body,
                                m.mapping_id
                            );
                        } else {
                            await APIClient.identity_providers.mappings.create(
                                providerId,
                                body
                            );
                        }
                    }

                    // Sync domains: delete removed, update existing, create new.
                    const keptDomainIds = domainsFromForm
                        .map(d => d.identity_provider_domain_id)
                        .filter(Boolean);
                    for (const id of originalDomainIds.value.filter(
                        id => !keptDomainIds.includes(id)
                    )) {
                        await APIClient.identity_providers.domains.delete(
                            providerId,
                            id
                        );
                    }
                    for (const d of domainsFromForm) {
                        const body = {
                            domain: d.domain || null,
                            allow_opac: d.allow_opac || false,
                            allow_staff: d.allow_staff || false,
                            auto_register_opac: d.auto_register_opac || false,
                            auto_register_staff: d.auto_register_staff || false,
                            update_on_auth: d.update_on_auth || false,
                            send_welcome_email: d.send_welcome_email || false,
                            default_library_id: d.default_library_id || null,
                            default_category_id: d.default_category_id || null,
                        };
                        if (d.identity_provider_domain_id) {
                            await APIClient.identity_providers.domains.update(
                                providerId,
                                body,
                                d.identity_provider_domain_id
                            );
                        } else {
                            await APIClient.identity_providers.domains.create(
                                providerId,
                                body
                            );
                        }
                    }

                    baseResource.setMessage($__("Identity provider updated"));
                    return updatedProvider;
                } else {
                    const newProvider =
                        await baseResource.apiClient.create(provider);
                    const newId = newProvider.identity_provider_id;

                    // Create a bridge record for each linked hostname
                    for (const h of hostnamesFromForm) {
                        await APIClient.identity_providers.hostnames.create(
                            newId,
                            {
                                hostname: h.hostname,
                                is_enabled: true,
                                is_exclusive: h.is_exclusive ?? false,
                                matchpoint: h.matchpoint || null,
                            }
                        );
                    }

                    // Create each attribute mapping
                    for (const m of mappingsFromForm) {
                        await APIClient.identity_providers.mappings.create(
                            newId,
                            {
                                provider_field: m.provider_field || null,
                                koha_field: m.koha_field,
                                default_content: m.default_content || null,
                            }
                        );
                    }

                    // Create each domain rule
                    for (const d of domainsFromForm) {
                        await APIClient.identity_providers.domains.create(
                            newId,
                            {
                                domain: d.domain || null,
                                allow_opac: d.allow_opac || false,
                                allow_staff: d.allow_staff || false,
                                auto_register_opac:
                                    d.auto_register_opac || false,
                                auto_register_staff:
                                    d.auto_register_staff || false,
                                update_on_auth: d.update_on_auth || false,
                                send_welcome_email:
                                    d.send_welcome_email || false,
                                default_library_id:
                                    d.default_library_id || null,
                                default_category_id:
                                    d.default_category_id || null,
                            }
                        );
                    }

                    baseResource.setMessage($__("Identity provider created"));
                    return newProvider;
                }
            } catch (error) {
                // errors surfaced by the httpClient
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
