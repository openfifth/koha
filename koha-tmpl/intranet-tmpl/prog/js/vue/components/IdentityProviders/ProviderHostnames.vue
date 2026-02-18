<template>
    <div class="page-section">
        <h4>{{ $__("Hostnames") }}</h4>
        <p class="text-muted">
            {{
                $__(
                    "Koha will surface this provider on login pages served from the linked hostnames. A hostname may be linked to multiple providers."
                )
            }}
        </p>

        <div v-if="loading" class="loading">{{ $__("Loading...") }}</div>
        <template v-else>
            <button class="btn btn-default mb-2" @click="openAddModal">
                <i class="fa fa-plus"></i>
                {{ $__("Add hostname") }}
            </button>
            <KohaTable
                :key="tableKey"
                :data="virtualRows"
                :columns="columns"
                :actions="tableActions"
                :options="tableOptions"
                @link="onLink"
                @edit="onEdit"
                @enable="onEnable"
                @disable="onDisable"
                @remove="onRemove"
            />
        </template>
    </div>
</template>

<script>
import { ref, computed, inject, onMounted } from "vue";
import KohaTable from "../KohaTable.vue";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "ProviderHostnames",
    components: { KohaTable },
    props: {
        providerId: {
            type: Number,
            required: true,
        },
    },
    setup(props) {
        const mainStore = inject("mainStore");
        const { setConfirmationDialog, setMessage } = mainStore;

        const allRows = ref([]);
        const providers = ref([]);
        const loading = ref(true);
        const tableKey = ref(0);

        const defaultHostnames = window.idp_default_hostnames || [];

        const fetchData = async () => {
            loading.value = true;
            try {
                const [hostnameList, providerList] = await Promise.all([
                    APIClient.identity_providers.hostnames.getAll(),
                    APIClient.identity_providers.providers.getAll(),
                ]);
                allRows.value = hostnameList;
                providers.value = providerList;
                tableKey.value++;
            } catch (e) {
                // errors surfaced by httpClient
            } finally {
                loading.value = false;
            }
        };

        const providerDescription = id => {
            const p = providers.value.find(p => p.identity_provider_id === id);
            return p ? p.description : `#${id}`;
        };

        // Build one virtual row per unique hostname string.
        // Each virtual row holds this provider's association (if any) plus a
        // list of other providers that also use the same hostname.
        // Default hostnames (from OPACBaseURL / staffClientBaseURL) are always
        // shown even when no database rows exist for them yet.
        const virtualRows = computed(() => {
            const byHostname = {};

            defaultHostnames.forEach(hostname => {
                byHostname[hostname] = {
                    hostname,
                    hostname_id: null,
                    is_linked: false,
                    is_enabled: false,
                    other_providers: [],
                };
            });

            allRows.value.forEach(row => {
                if (!byHostname[row.hostname]) {
                    byHostname[row.hostname] = {
                        hostname: row.hostname,
                        // This provider's association fields (null when not linked)
                        hostname_id: null,
                        is_linked: false,
                        is_enabled: false,
                        // Other providers that share this hostname
                        other_providers: [],
                    };
                }
                if (row.identity_provider_id === props.providerId) {
                    byHostname[row.hostname].hostname_id =
                        row.identity_provider_hostname_id;
                    byHostname[row.hostname].is_linked = true;
                    byHostname[row.hostname].is_enabled = row.is_enabled;
                } else {
                    byHostname[row.hostname].other_providers.push(
                        providerDescription(row.identity_provider_id)
                    );
                }
            });

            return Object.values(byHostname).sort((a, b) => {
                // Linked (active) first, then linked (inactive), then unlinked
                if (a.is_linked !== b.is_linked) return a.is_linked ? -1 : 1;
                if (a.is_linked && a.is_enabled !== b.is_enabled)
                    return a.is_enabled ? -1 : 1;
                return a.hostname.localeCompare(b.hostname);
            });
        });

        const columns = [
            {
                title: $__("Hostname"),
                data: "hostname",
                searchable: true,
                orderable: true,
            },
            {
                title: $__("Status"),
                data: "is_linked",
                searchable: false,
                orderable: false,
                render: (data, type, row) => {
                    if (!row.is_linked) return "—";
                    return row.is_enabled
                        ? `<span class="badge bg-success">${$__("Active")}</span>`
                        : `<span class="badge bg-warning text-dark">${$__("Inactive")}</span>`;
                },
            },
            {
                title: $__("Also used by"),
                data: "other_providers",
                searchable: false,
                orderable: false,
                render: (data, type, row) => {
                    if (!row.other_providers.length) return "";
                    return row.other_providers
                        .map(
                            name =>
                                `<span class="badge bg-info text-dark">${name}</span>`
                        )
                        .join(" ");
                },
            },
        ];

        const tableActions = {
            "-1": [
                {
                    link: {
                        text: $__("Link to this provider"),
                        icon: "fa fa-link",
                        should_display: row => !row.is_linked,
                    },
                },
                {
                    edit: {
                        text: $__("Edit"),
                        icon: "fa fa-pencil",
                        should_display: row => row.is_linked,
                    },
                },
                {
                    enable: {
                        text: $__("Enable"),
                        icon: "fa fa-toggle-off",
                        should_display: row => row.is_linked && !row.is_enabled,
                    },
                },
                {
                    disable: {
                        text: $__("Disable"),
                        icon: "fa fa-toggle-on",
                        should_display: row => row.is_linked && row.is_enabled,
                    },
                },
                {
                    remove: {
                        text: $__("Remove from this provider"),
                        icon: "fa fa-unlink",
                        should_display: row => row.is_linked,
                    },
                },
            ],
        };

        const tableOptions = {
            paging: false,
            searching: false,
            info: false,
        };

        const openAddModal = () => {
            setConfirmationDialog(
                {
                    title: $__("Add hostname"),
                    accept_label: $__("Add"),
                    cancel_label: $__("Cancel"),
                    inputs: [
                        {
                            name: "hostname",
                            type: "text",
                            label: $__("Hostname"),
                            required: true,
                            value: "",
                        },
                    ],
                },
                async (confirmation, inputFields) => {
                    const hostname = (inputFields.hostname || "").trim();
                    if (!hostname) return;
                    await APIClient.identity_providers.hostnames.create({
                        hostname,
                        identity_provider_id: props.providerId,
                        is_enabled: true,
                    });
                    setMessage($__("Hostname added"));
                    await fetchData();
                }
            );
        };

        // Link an existing hostname (already used by another provider) to this one
        const onLink = async row => {
            await APIClient.identity_providers.hostnames.create({
                hostname: row.hostname,
                identity_provider_id: props.providerId,
                is_enabled: true,
            });
            setMessage($__("Hostname linked to this provider"));
            await fetchData();
        };

        const onEdit = row => {
            setConfirmationDialog(
                {
                    title: $__("Edit hostname"),
                    accept_label: $__("Save"),
                    cancel_label: $__("Cancel"),
                    inputs: [
                        {
                            name: "hostname",
                            type: "text",
                            label: $__("Hostname"),
                            required: true,
                            value: row.hostname,
                        },
                    ],
                },
                async (confirmation, inputFields) => {
                    const hostname = (inputFields.hostname || "").trim();
                    if (!hostname) return;
                    await APIClient.identity_providers.hostnames.update(
                        {
                            hostname,
                            identity_provider_id: props.providerId,
                            is_enabled: row.is_enabled,
                        },
                        row.hostname_id
                    );
                    setMessage($__("Hostname updated"));
                    await fetchData();
                }
            );
        };

        const onEnable = async row => {
            await APIClient.identity_providers.hostnames.update(
                {
                    hostname: row.hostname,
                    identity_provider_id: props.providerId,
                    is_enabled: true,
                },
                row.hostname_id
            );
            await fetchData();
        };

        const onDisable = async row => {
            await APIClient.identity_providers.hostnames.update(
                {
                    hostname: row.hostname,
                    identity_provider_id: props.providerId,
                    is_enabled: false,
                },
                row.hostname_id
            );
            await fetchData();
        };

        const onRemove = row => {
            setConfirmationDialog(
                {
                    title: $__("Remove hostname"),
                    message: $__(
                        "Remove '%s' from this provider? Other providers using this hostname will not be affected."
                    ).replace("%s", row.hostname),
                    accept_label: $__("Yes, remove"),
                    cancel_label: $__("Cancel"),
                },
                async () => {
                    await APIClient.identity_providers.hostnames.delete(
                        row.hostname_id
                    );
                    setMessage($__("Hostname removed from this provider"));
                    await fetchData();
                }
            );
        };

        onMounted(fetchData);

        return {
            loading,
            tableKey,
            virtualRows,
            columns,
            tableActions,
            tableOptions,
            openAddModal,
            onLink,
            onEdit,
            onEnable,
            onDisable,
            onRemove,
        };
    },
};
</script>
