<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <BaseResource v-else :routeAction="routeAction" :instancedResource="this" />

    <!-- SAML2 certificate generation modal -->
    <div
        v-if="certModalVisible"
        class="modal fade show d-block"
        tabindex="-1"
        role="dialog"
        aria-modal="true"
        @click.self="certModalVisible = false"
    >
        <div class="modal-dialog" role="document">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">
                        {{ $__("Generate SP certificate") }}
                    </h5>
                    <button
                        type="button"
                        class="btn-close"
                        @click="certModalVisible = false"
                        :aria-label="$__('Close')"
                    ></button>
                </div>
                <div class="modal-body">
                    <div class="mb-3">
                        <label class="form-label" for="cert-cn">{{
                            $__("Common Name (CN)")
                        }}</label>
                        <input
                            id="cert-cn"
                            type="text"
                            class="form-control"
                            v-model="certOptions.common_name"
                        />
                        <div class="form-text">
                            {{
                                $__(
                                    "Used as the certificate subject. Typically the hostname URL (e.g. https://library.example.com)."
                                )
                            }}
                        </div>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="cert-keysize">{{
                            $__("Key size")
                        }}</label>
                        <select
                            id="cert-keysize"
                            class="form-select"
                            v-model="certOptions.key_size"
                        >
                            <option :value="2048">2048 bits</option>
                            <option :value="4096">4096 bits</option>
                        </select>
                    </div>
                    <div class="mb-3">
                        <label class="form-label" for="cert-validity">{{
                            $__("Validity (days)")
                        }}</label>
                        <input
                            id="cert-validity"
                            type="number"
                            class="form-control"
                            min="1"
                            max="3650"
                            v-model.number="certOptions.validity_days"
                        />
                    </div>
                    <div
                        v-if="certError"
                        class="alert alert-danger"
                        role="alert"
                    >
                        {{ certError }}
                    </div>
                </div>
                <div class="modal-footer">
                    <button
                        type="button"
                        class="btn btn-secondary"
                        @click="certModalVisible = false"
                        :disabled="certGenerating"
                    >
                        {{ $__("Cancel") }}
                    </button>
                    <button
                        type="button"
                        class="btn btn-primary"
                        @click="generateCertificate"
                        :disabled="certGenerating"
                    >
                        <span v-if="certGenerating">{{
                            $__("Generating…")
                        }}</span>
                        <span v-else>{{ $__("Generate") }}</span>
                    </button>
                </div>
            </div>
        </div>
    </div>
    <div v-if="certModalVisible" class="modal-backdrop fade show"></div>
</template>

<script>
import { ref, onMounted, reactive, watch, computed } from "vue";
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
            name: "mode",
            label: __("Mode"),
            required: true,
            type: "select",
            group: "SAML2 settings",
            options: [
                { value: "ipc", label: "IPC (OS-level mod_shib / libshibsp)" },
                { value: "native", label: "Native (Koha built-in SAML2 SP)" },
            ],
            requiredKey: "value",
            selectLabel: "label",
            toolTip: __(
                "IPC mode requires mod_shib installed on the server. Native mode uses Koha's built-in SAML2 service provider."
            ),
        },
        {
            name: "idp_metadata",
            label: __("IdP Metadata XML"),
            type: "textarea",
            group: "SAML2 settings",
            nativeOnly: true,
            toolTip: __(
                "Paste the Identity Provider's SAML2 metadata XML here. Required for native mode."
            ),
        },
        {
            name: "generate_sp_cert",
            label: __("Generate certificate"),
            buttonLabel: __("Generate certificate…"),
            type: "action_button",
            group: "SAML2 settings",
            nativeOnly: true,
            toolTip: __(
                "Generate a self-signed X.509 certificate and private key for this SP"
            ),
            // onClick is set dynamically in setup() once certModalVisible is in scope
        },
        {
            name: "sp_cert",
            label: __("SP Certificate (PEM)"),
            type: "pem_certificate",
            group: "SAML2 settings",
            nativeOnly: true,
            toolTip: __(
                "The Service Provider's X.509 certificate in PEM format. Required for native mode."
            ),
        },
        {
            name: "sp_key",
            label: __("SP Private Key (PEM)"),
            type: "pem_certificate",
            group: "SAML2 settings",
            nativeOnly: true,
            toolTip: __(
                "The Service Provider's private key in PEM format. Required for native mode."
            ),
        },
        {
            name: "sign_authn_requests",
            label: __("Sign AuthnRequests"),
            type: "boolean",
            group: "SAML2 settings",
            nativeOnly: true,
            toolTip: __(
                "Sign outgoing SAML2 AuthnRequests with the SP certificate. Recommended when using native mode."
            ),
        },
        {
            name: "debug",
            label: __("Debug mode"),
            type: "boolean",
            group: "SAML2 settings",
            nativeOnly: true,
            toolTip: __(
                "When enabled, the /auth/saml2/attributes page shows received SAML attributes and matchpoint resolution to help configure attribute mappings. Access is restricted by IP address. Disable in production."
            ),
        },
        {
            name: "debug_allowed_ips",
            label: __("Debug allowed IPs"),
            type: "text",
            group: "SAML2 settings",
            nativeOnly: true,
            debugOnly: true,
            toolTip: __(
                "Space-separated IP addresses or CIDR ranges allowed to view the debug page (e.g. '127.0.0.1 ::1 192.168.1.0/24'). Defaults to localhost only when empty."
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

        // Certificate generation modal state
        const certModalVisible = ref(false);
        const certGenerating = ref(false);
        const certError = ref(null);
        const certOptions = reactive({
            common_name: "",
            key_size: 2048,
            validity_days: 365,
        });

        // Tracks the currently selected/loaded protocol so config field groups
        // can be shown or hidden reactively via hideIn closures.
        const selectedProtocol = ref(null);

        // Tracks the SAML2 mode (ipc/native) so mode-specific config fields
        // can be shown or hidden reactively via hideIn closures.
        const selectedSAML2Mode = ref(null);

        // Tracks whether SAML2 debug mode is enabled so the debug_allowed_ips
        // field can be shown or hidden reactively via hideIn closures.
        const selectedDebugMode = ref(null);

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
        // Fields marked nativeOnly:true are additionally hidden unless the
        // SAML2 mode is set to "native" (tracked via selectedSAML2Mode).
        const configResourceAttrs = Object.entries(
            PROTOCOL_CONFIG_FIELDS
        ).flatMap(([protocol, fields]) =>
            fields.map(f => {
                const attr = {
                    ...f,
                    name: `_config_${f.name}`,
                    hideIn: () => {
                        // Protocol-level check: always hide when another protocol is selected
                        if (
                            !selectedProtocol.value ||
                            selectedProtocol.value !== protocol
                        ) {
                            return ["Form", "Show", "List"];
                        }
                        // Mode-level check for nativeOnly fields (e.g. SAML2 SP crypto config)
                        if (
                            f.nativeOnly &&
                            selectedSAML2Mode.value !== "native"
                        ) {
                            return ["Form", "Show", "List"];
                        }
                        // Debug-level check: debugOnly fields only visible when debug is enabled
                        if (f.debugOnly && !selectedDebugMode.value) {
                            return ["Form", "Show", "List"];
                        }
                        // showOnly fields are hidden in the edit/add form
                        if (f.showOnly) {
                            return ["Form", "List"];
                        }
                        return ["List"];
                    },
                };
                // Inject the onClick handler for the cert-generation button
                if (f.name === "generate_sp_cert") {
                    attr.onClick = resource => {
                        certError.value = null;
                        // Pre-populate CN with the first configured hostname
                        const firstHostname =
                            resource.hostnames?.[0]?.hostname || "";
                        certOptions.common_name = firstHostname
                            ? "https://" + firstHostname
                            : "";
                        certOptions.key_size = 2048;
                        certOptions.validity_days = 365;
                        certModalVisible.value = true;
                    };
                }
                return attr;
            })
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

        // Dynamic columns for the hostnames display table.
        // For SAML2 native mode a "SP Metadata URL" column is appended so
        // administrators can easily copy the URL to share with their IdP.
        const hostnameColumns = computed(() => {
            const cols = [
                { name: __("Hostname"), value: "hostname" },
                { name: __("Force SSO"), value: "force_sso" },
                { name: __("Matchpoint"), value: "matchpoint" },
            ];
            if (selectedSAML2Mode.value === "native") {
                cols.push({
                    name: __("SP Metadata URL"),
                    value: "metadata_url",
                    computeHref: row => row.metadata_url,
                });
            }
            return cols;
        });

        const hostnameAttr = {
            name: "hostnames",
            type: "relationshipWidget",
            group: "Network & Entry Settings",
            hideIn: ["List"],
            showElement: {
                type: "table",
                columnData: "hostnames",
                hidden: provider => !!provider.hostnames?.length,
                columns: hostnameColumns,
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
                    { name: __("Sync on creation"), value: "sync_on_creation" },
                    { name: __("Sync on update"), value: "sync_on_update" },
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
                        sync_on_creation: true,
                        sync_on_update: true,
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
                {
                    name: "sync_on_creation",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Sync on creation"),
                    badgeTrueLabel: __("Sync on creation"),
                    badgeTrueClass: "bg-success",
                    toolTip: __(
                        "Populate this field when a new patron account is created via SSO. Only applies when 'Auto-register' is enabled in the matching Email Domain Rule."
                    ),
                },
                {
                    name: "sync_on_update",
                    type: "boolean",
                    indexRequired: true,
                    label: __("Sync on update"),
                    badgeTrueLabel: __("Sync on update"),
                    badgeTrueClass: "bg-success",
                    toolTip: __(
                        "Update this field on every login. Only applies when 'Update patron data on login' is enabled in the matching Email Domain Rule."
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
            activeFormResource.value = resource;
            selectedProtocol.value = resource.protocol || null;
            const config = resource.config || {};
            // Track SAML2 mode and debug state for reactive field visibility
            if (resource.protocol === "SAML2") {
                selectedSAML2Mode.value = config.mode || null;
                selectedDebugMode.value = config.debug || null;
            } else {
                selectedSAML2Mode.value = null;
                selectedDebugMode.value = null;
            }
            const fields = PROTOCOL_CONFIG_FIELDS[resource.protocol] || [];
            fields.forEach(field => {
                if (field.type === "group_placeholder") return;
                if (field.type === "action_button") return;
                if (field.type === "static_text") return;
                resource[`_config_${field.name}`] =
                    field.type === "boolean"
                        ? (config[field.name] ?? false)
                        : (config[field.name] ?? "");
            });
            if (!resource.domains) resource.domains = [];
            if (!resource.mappings) resource.mappings = [];
            resource.hostnames = resource.hostnames || [];

            // For SAML2 native mode, add computed metadata_url to each hostname
            // so it can be displayed in the hostnames table.
            if (resource.protocol === "SAML2" && config.mode === "native") {
                resource.hostnames.forEach(h => {
                    if (h.hostname) {
                        h.metadata_url =
                            "https://" +
                            h.hostname +
                            "/cgi-bin/koha/saml2/metadata";
                    }
                });
            }

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

        // Always points to the object currently bound to the form:
        // - add mode:  newResource.value (the template object above)
        // - edit mode: the fetched resource (updated in afterResourceFetch)
        const activeFormResource = ref(baseResource.newResource.value);
        watch(
            () => formStateObj.protocol,
            newProtocol => {
                selectedProtocol.value = newProtocol || null;
                // Reset SAML2 mode and debug tracking when protocol changes
                if (!newProtocol || newProtocol !== "SAML2") {
                    selectedSAML2Mode.value = null;
                    selectedDebugMode.value = null;
                }
            }
        );
        // Watch the SAML2 mode field so native-only fields appear/disappear reactively.
        // The mode field is stored as _config_mode in the form state object.
        // The value may be a plain string (on load) or a select option object {value, label}
        // (when picked from the dropdown), so we normalise to a string.
        watch(
            () => formStateObj._config_mode,
            newMode => {
                const modeStr =
                    newMode && typeof newMode === "object"
                        ? newMode.value
                        : newMode || null;
                selectedSAML2Mode.value = modeStr;
            }
        );
        // Watch the SAML2 debug flag so debug_allowed_ips appears/disappears reactively.
        watch(
            () => formStateObj._config_debug,
            newDebug => {
                selectedDebugMode.value = newDebug || null;
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

        const generateCertificate = async () => {
            certError.value = null;
            certGenerating.value = true;
            try {
                const result =
                    await APIClient.identity_providers.saml2.generateCertificate(
                        {
                            common_name: certOptions.common_name,
                            key_size: certOptions.key_size,
                            validity_days: certOptions.validity_days,
                        }
                    );
                activeFormResource.value._config_sp_cert = result.certificate;
                activeFormResource.value._config_sp_key = result.private_key;
                certModalVisible.value = false;
            } catch (err) {
                certError.value =
                    err?.message || $__("Certificate generation failed");
            } finally {
                certGenerating.value = false;
            }
        };

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
                if (field.type === "action_button") return;
                if (field.type === "static_text") return;
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
                            sync_on_creation: m.sync_on_creation ?? true,
                            sync_on_update: m.sync_on_update ?? true,
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
                                sync_on_creation: m.sync_on_creation ?? true,
                                sync_on_update: m.sync_on_update ?? true,
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
                // httpClient displays the alert; re-throw so
                // ResourceFormSave knows the save failed.
                throw error;
            }
        };

        return {
            ...baseResource,
            initialized,
            PROTOCOL_CONFIG_FIELDS,
            tableOptions,
            onFormSave,
            certModalVisible,
            certGenerating,
            certError,
            certOptions,
            generateCertificate,
        };
    },
};
</script>
