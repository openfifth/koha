<template>
    <div class="page-section">
        <h4>{{ $__("Hostnames") }}</h4>
        <p class="text-muted">
            {{
                $__(
                    "When a user accesses Koha via one of these hostnames, they will be directed to the assigned identity provider. A hostname can be assigned to one provider at a time."
                )
            }}
        </p>

        <form class="mb-3" @submit.prevent="addHostname">
            <div class="input-group">
                <input
                    v-model="newHostnameValue"
                    type="text"
                    class="form-control"
                    :placeholder="$__('e.g. opac.library.org')"
                    :aria-label="$__('New hostname')"
                />
                <button
                    type="submit"
                    class="btn btn-primary"
                    :disabled="!newHostnameValue.trim()"
                >
                    <i class="fa fa-plus"></i>
                    {{ $__("Add hostname") }}
                </button>
            </div>
        </form>

        <div v-if="loading" class="loading">{{ $__("Loading...") }}</div>

        <table v-else-if="allHostnames.length" class="table table-bordered">
            <thead>
                <tr>
                    <th>{{ $__("Hostname") }}</th>
                    <th>{{ $__("Status") }}</th>
                    <th class="noExport">{{ $__("Actions") }}</th>
                </tr>
            </thead>
            <tbody>
                <tr
                    v-for="h in sortedHostnames"
                    :key="h.identity_provider_hostname_id"
                    :class="rowClass(h)"
                >
                    <td>
                        <span
                            v-if="editingId !== h.identity_provider_hostname_id"
                            >{{ h.hostname }}</span
                        >
                        <input
                            v-else
                            v-model="editHostnameValue"
                            type="text"
                            class="form-control form-control-sm"
                            @keydown.enter.prevent="saveEdit(h)"
                            @keydown.escape="cancelEdit"
                        />
                    </td>
                    <td>
                        <span
                            v-if="isThisProvider(h) && h.is_enabled"
                            class="badge bg-success"
                        >
                            {{ $__("Active") }}
                        </span>
                        <span
                            v-else-if="isThisProvider(h) && !h.is_enabled"
                            class="badge bg-warning text-dark"
                        >
                            {{ $__("Inactive") }}
                        </span>
                        <span
                            v-else-if="!h.identity_provider_id"
                            class="badge bg-secondary"
                        >
                            {{ $__("Available") }}
                        </span>
                        <span v-else class="badge bg-info text-dark">
                            {{
                                $__("Used by %s").replace(
                                    "%s",
                                    providerName(h.identity_provider_id)
                                )
                            }}
                        </span>
                    </td>
                    <td class="noExport">
                        <!-- Editing state -->
                        <template
                            v-if="editingId === h.identity_provider_hostname_id"
                        >
                            <button
                                class="btn btn-xs btn-primary"
                                @click="saveEdit(h)"
                            >
                                {{ $__("Save") }}
                            </button>
                            <button
                                class="btn btn-xs btn-default"
                                @click="cancelEdit"
                            >
                                {{ $__("Cancel") }}
                            </button>
                        </template>

                        <!-- This provider's hostname -->
                        <template v-else-if="isThisProvider(h)">
                            <button
                                class="btn btn-xs btn-default"
                                @click="startEdit(h)"
                            >
                                <i class="fa fa-pencil"></i>
                                {{ $__("Edit") }}
                            </button>
                            <button
                                class="btn btn-xs btn-default"
                                @click="toggleEnabled(h)"
                            >
                                <i
                                    :class="
                                        h.is_enabled
                                            ? 'fa fa-toggle-on'
                                            : 'fa fa-toggle-off'
                                    "
                                ></i>
                                {{
                                    h.is_enabled
                                        ? $__("Disable")
                                        : $__("Enable")
                                }}
                            </button>
                            <button
                                class="btn btn-xs btn-default"
                                @click="unassign(h)"
                            >
                                {{ $__("Unassign") }}
                            </button>
                            <button
                                class="btn btn-xs btn-danger"
                                @click="deleteHostname(h)"
                            >
                                <i class="fa fa-trash"></i>
                                {{ $__("Delete") }}
                            </button>
                        </template>

                        <!-- Available (unassigned) hostname -->
                        <template v-else-if="!h.identity_provider_id">
                            <button
                                class="btn btn-xs btn-default"
                                @click="startEdit(h)"
                            >
                                <i class="fa fa-pencil"></i>
                                {{ $__("Edit") }}
                            </button>
                            <button
                                class="btn btn-xs btn-success"
                                @click="assign(h)"
                            >
                                <i class="fa fa-link"></i>
                                {{ $__("Assign to this provider") }}
                            </button>
                            <button
                                class="btn btn-xs btn-danger"
                                @click="deleteHostname(h)"
                            >
                                <i class="fa fa-trash"></i>
                                {{ $__("Delete") }}
                            </button>
                        </template>

                        <!-- Another provider owns this hostname -->
                        <span v-else class="text-muted">—</span>
                    </td>
                </tr>
            </tbody>
        </table>

        <div v-else-if="!loading" class="alert alert-info" role="alert">
            {{
                $__(
                    "No hostnames are configured yet. Add one above to enable automatic provider selection based on the server hostname."
                )
            }}
        </div>
    </div>
</template>

<script>
import { ref, computed, onMounted } from "vue";
import { APIClient } from "../../fetch/api-client.js";
import { $__ } from "@koha-vue/i18n";

export default {
    name: "ProviderHostnames",
    props: {
        providerId: {
            type: Number,
            required: true,
        },
    },
    setup(props) {
        const allHostnames = ref([]);
        const providers = ref([]);
        const loading = ref(true);
        const newHostnameValue = ref("");
        const editingId = ref(null);
        const editHostnameValue = ref("");

        const fetchData = async () => {
            loading.value = true;
            try {
                const [hostnameList, providerList] = await Promise.all([
                    APIClient.identity_providers.hostnames.getAll(),
                    APIClient.identity_providers.providers.getAll(),
                ]);
                allHostnames.value = hostnameList;
                providers.value = providerList;
            } catch (e) {
                // errors surfaced by httpClient
            } finally {
                loading.value = false;
            }
        };

        const isThisProvider = h => h.identity_provider_id === props.providerId;

        const providerName = id => {
            const p = providers.value.find(p => p.identity_provider_id === id);
            return p ? p.description : `#${id}`;
        };

        // Sort: this provider's entries first (active, then inactive),
        // then available (unassigned), then other providers' entries
        const sortedHostnames = computed(() =>
            [...allHostnames.value].sort((a, b) => {
                const score = h => {
                    if (isThisProvider(h)) return h.is_enabled ? 0 : 1;
                    if (!h.identity_provider_id) return 2;
                    return 3;
                };
                const d = score(a) - score(b);
                return d !== 0 ? d : a.hostname.localeCompare(b.hostname);
            })
        );

        const rowClass = h => {
            if (isThisProvider(h))
                return h.is_enabled ? "table-success" : "table-warning";
            return "";
        };

        const addHostname = async () => {
            const hostname = newHostnameValue.value.trim();
            if (!hostname) return;
            try {
                await APIClient.identity_providers.hostnames.create({
                    hostname,
                    identity_provider_id: props.providerId,
                    is_enabled: true,
                });
                newHostnameValue.value = "";
                await fetchData();
            } catch (e) {}
        };

        const startEdit = h => {
            editingId.value = h.identity_provider_hostname_id;
            editHostnameValue.value = h.hostname;
        };

        const cancelEdit = () => {
            editingId.value = null;
            editHostnameValue.value = "";
        };

        const saveEdit = async h => {
            const hostname = editHostnameValue.value.trim();
            if (!hostname) return;
            try {
                await APIClient.identity_providers.hostnames.update(
                    {
                        hostname,
                        identity_provider_id: h.identity_provider_id,
                        is_enabled: h.is_enabled,
                    },
                    h.identity_provider_hostname_id
                );
                editingId.value = null;
                await fetchData();
            } catch (e) {}
        };

        const toggleEnabled = async h => {
            try {
                await APIClient.identity_providers.hostnames.update(
                    {
                        hostname: h.hostname,
                        identity_provider_id: h.identity_provider_id,
                        is_enabled: !h.is_enabled,
                    },
                    h.identity_provider_hostname_id
                );
                await fetchData();
            } catch (e) {}
        };

        const assign = async h => {
            try {
                await APIClient.identity_providers.hostnames.update(
                    {
                        hostname: h.hostname,
                        identity_provider_id: props.providerId,
                        is_enabled: true,
                    },
                    h.identity_provider_hostname_id
                );
                await fetchData();
            } catch (e) {}
        };

        const unassign = async h => {
            try {
                await APIClient.identity_providers.hostnames.update(
                    {
                        hostname: h.hostname,
                        identity_provider_id: null,
                        is_enabled: false,
                    },
                    h.identity_provider_hostname_id
                );
                await fetchData();
            } catch (e) {}
        };

        const deleteHostname = async h => {
            if (
                !confirm(
                    $__(
                        "Are you sure you want to delete this hostname? This will remove it from the system entirely."
                    )
                )
            )
                return;
            try {
                await APIClient.identity_providers.hostnames.delete(
                    h.identity_provider_hostname_id
                );
                await fetchData();
            } catch (e) {}
        };

        onMounted(fetchData);

        return {
            allHostnames,
            loading,
            newHostnameValue,
            editingId,
            editHostnameValue,
            sortedHostnames,
            isThisProvider,
            providerName,
            rowClass,
            addHostname,
            startEdit,
            cancelEdit,
            saveEdit,
            toggleEnabled,
            assign,
            unassign,
            deleteHostname,
        };
    },
};
</script>
