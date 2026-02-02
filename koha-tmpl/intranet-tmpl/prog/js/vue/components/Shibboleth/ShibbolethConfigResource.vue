<template>
    <div v-if="!initialized">{{ $__("Loading") }}</div>
    <BaseResource v-else :routeAction="routeAction" :instancedResource="this" />
</template>

<script>
import { inject, ref, onMounted, reactive } from "vue";
import BaseResource from "./../BaseResource.vue";
import { useBaseResource } from "../../composables/base-resource.js";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "ShibbolethConfigResource",
    components: {
        BaseResource,
    },
    props: {
        routeAction: String,
    },
    emits: ["select-resource"],
    setup(props) {
        const initialized = ref(false);
        const configData = ref(null);
        const resourceAttrs = [
            {
                name: "force_opac_sso",
                type: "boolean",
                label: __("Force OPAC SSO"),
                group: "SSO Settings",
                toolTip: __(
                    "Automatically redirect OPAC users to Shibboleth login"
                ),
            },
            {
                name: "force_staff_sso",
                type: "boolean",
                label: __("Force staff SSO"),
                group: "SSO Settings",
                toolTip: __(
                    "Automatically redirect staff users to Shibboleth login"
                ),
            },
            {
                name: "autocreate",
                type: "boolean",
                label: __("Auto create users"),
                group: "User Management",
                toolTip: __(
                    "Automatically create patron records for new Shibboleth users"
                ),
            },
            {
                name: "sync",
                type: "boolean",
                label: __("Sync user attributes"),
                group: "User Management",
                toolTip: __(
                    "Update patron attributes from Shibboleth on each login"
                ),
            },
            {
                name: "welcome",
                type: "boolean",
                label: __("Send welcome email"),
                group: "User Management",
                toolTip: __(
                    "Send welcome email to new users created via Shibboleth"
                ),
            },
        ];

        const baseResource = useBaseResource({
            resourceName: "config",
            nameAttr: "shibboleth_config_id",
            idAttr: "shibboleth_config_id",
            components: {
                show: "ShibbolethConfigShow",
                list: "ShibbolethHome",
                add: "ShibbolethConfigFormAdd",
                edit: "ShibbolethConfigFormEdit",
            },
            apiClient: APIClient.shibboleth.config,
            i18n: {
                displayName: $__("Shibboleth Configuration"),
                editLabel: $__("Edit Shibboleth Configuration"),
            },
            stickyToolbar: ["Form"],
            embedded: props.embedded,
            formGroupsDisplayMode: "accordion",
            resourceAttrs,
            props,
            moduleStore: "ShibbolethStore",
        });

        const onFormSave = async (e, configToSave) => {
            e.preventDefault();

            const config = JSON.parse(JSON.stringify(configToSave));
            delete config.shibboleth_config_id;

            const client = APIClient.shibboleth.config;

            try {
                await client.update(config);
                baseResource.setMessage(__("Configuration updated"));
                baseResource.router.push({ name: "ShibbolethHome" });
            } catch (error) {
                // Errors handled by base resource
            }
        };

        // Fetch the singleton config on mount and replace newResource getter
        onMounted(async () => {
            try {
                configData.value = await APIClient.shibboleth.config.get();
                initialized.value = true;
            } catch (error) {
                console.error("Failed to load config:", error);
                initialized.value = true;
            }
        });

        return {
            ...baseResource,
            initialized,
            onFormSave,
            get newResource() {
                return configData.value || baseResource.newResource;
            },
        };
    },
};
</script>
