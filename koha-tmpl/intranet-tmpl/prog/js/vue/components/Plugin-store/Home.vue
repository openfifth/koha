<template>
    <div id="plugin_home">
        <div class="btn-toolbar" id="toolbar">
            <button
                v-if="isUserPermitted('CAN_user_plugins_manage')"
                class="btn btn-default"
                @click="openSearchModal"
            >
                <i class="fa-solid fa-magnifying-glass"></i> Search for new
                plugins
            </button>
            <button
                v-if="isUserPermitted('CAN_user_plugins_manage')"
                class="btn btn-default"
                @click="openUploadModal"
            >
                <i class="fa fa-upload"></i> Upload plugin
            </button>
            <button class="btn btn-default" @click="checkForUpdates">
                <i class="fa fa-refresh"></i> Check for updates
            </button>
            <select
                v-model="typeFilter"
                class="form-select w-auto d-inline"
                @change="onTypeFilterChange"
            >
                <option value="">All plugins</option>
                <option value="report">Report plugins</option>
                <option value="tool">Tool plugins</option>
                <option value="configure">Configurable plugins</option>
                <option value="admin">Admin plugins</option>
            </select>
        </div>

        <div class="page-section">
            <KohaTable
                ref="table"
                v-bind="tableOptions"
                @enable="doEnable"
                @disable="doDisable"
                @uninstall="doUninstall"
                @update="doUpdatePlugin"
            ></KohaTable>
        </div>
    </div>
</template>

<script>
import { inject, ref } from "vue";
import { storeToRefs } from "pinia";
import { APIClient } from "../../fetch/api-client.js";
import KohaTable from "../KohaTable.vue";

export default {
    setup() {
        const pluginStoreStore = inject("pluginStoreStore");
        const storeRefs = storeToRefs(pluginStoreStore);
        const { isUserPermitted } = pluginStoreStore;
        const { setMessage, setConfirmationDialog, setComponentDialog } =
            inject("mainStore");

        return {
            userPermissions: storeRefs.userPermissions,
            isUserPermitted,
            setMessage,
            setConfirmationDialog,
            setComponentDialog,
        };
    },
    data() {
        return {
            installedPlugins: [],
            storeCatalog: null,
            typeFilter: "",
            tableOptions: {
                columns: [
                    { title: "Name", data: "name" },
                    { title: "Description", data: "description" },
                    { title: "Author", data: "author" },
                    { title: "Version", data: "version" },
                    {
                        title: "Status",
                        data: "is_enabled",
                        render: (data, type, row) =>
                            data
                                ? '<span class="badge text-bg-success">Enabled</span>'
                                : '<span class="badge text-bg-warning">Disabled</span>',
                    },
                    {
                        title: "Update available",
                        data: "class",
                        render: (data, type, row) =>
                            this.updateAvailable(row)
                                ? '<span class="badge text-bg-warning">Update available</span>'
                                : "",
                    },
                ],
                url: () => this.table_url(),
                actions: this.getTableActions(),
                default_filters: {},
            },
        };
    },
    created() {
        const client = APIClient.plugin_store;
        client.plugins.getConfig().then(result => {
            this.userPermissions = result.permissions;
            this.$refs.table.redraw(this.table_url());
        });
        client.plugins.getAll().then(result => {
            this.installedPlugins = result;
        });
    },
    methods: {
        openSearchModal() {
            this.setComponentDialog({
                title: this.$__("Search for new plugins"),
                cancel_label: this.$__("Close"),
                componentPath:
                    "@koha-vue/components/Plugin-store/SearchModal.vue",
                componentProps: {
                    installed_plugins: this.installedPlugins,
                },
                componentListeners: {
                    installed: () => {
                        this.refreshList();
                        this.setComponentDialog(null);
                    },
                },
            });
        },
        openUploadModal() {
            this.setComponentDialog({
                title: this.$__("Upload plugin"),
                cancel_label: this.$__("Close"),
                componentPath:
                    "@koha-vue/components/Plugin-store/UploadModal.vue",
                componentListeners: {
                    uploaded: () => {
                        this.refreshList();
                        this.setComponentDialog(null);
                    },
                },
            });
        },
        getTableActions() {
            let component = this;
            return {
                "-1": [
                    {
                        disable: {
                            text: this.$__("Disable"),
                            icon: "fa fa-pause",
                            should_display: row => (row.is_enabled ? 1 : 0),
                        },
                    },
                    {
                        enable: {
                            text: this.$__("Enable"),
                            icon: "fa fa-play",
                            should_display: row => (row.is_enabled ? 0 : 1),
                        },
                    },
                    {
                        uninstall: {
                            text: this.$__("Uninstall"),
                            icon: "fa fa-trash-can",
                            should_display: () =>
                                component.isUserPermitted(
                                    "CAN_user_plugins_manage"
                                )
                                    ? 1
                                    : 0,
                        },
                    },
                    {
                        update: {
                            text: this.$__("Update"),
                            icon: "fa fa-refresh",
                            should_display: row =>
                                component.updateAvailable(row) ? 1 : 0,
                        },
                    },
                ],
            };
        },
        updateAvailable(row) {
            if (!this.storeCatalog) return false;
            const storeEntry = this.storeCatalog.find(
                p => p.class_name === row.class
            );
            if (!storeEntry || !storeEntry.releases?.length) return false;
            const mostRecent = storeEntry.releases.reduce((a, b) =>
                new Date(b.date_released) > new Date(a.date_released) ? b : a
            );
            return mostRecent.version !== row.version;
        },
        table_url() {
            return this.typeFilter
                ? `/api/v1/plugins?capability=${this.typeFilter}`
                : "/api/v1/plugins";
        },
        onTypeFilterChange() {
            this.$refs.table.redraw(this.table_url());
        },
        checkForUpdates() {
            const client = APIClient.plugin_store;
            client.plugins.getStoreAll(koha_version.release).then(result => {
                this.storeCatalog = result;
                this.$refs.table.redraw(this.table_url());
            });
        },
        doEnable(plugin) {
            this.setPluginEnabled(plugin, true);
        },
        doDisable(plugin) {
            this.setPluginEnabled(plugin, false);
        },
        setPluginEnabled(plugin, is_enabled) {
            const client = APIClient.plugin_store;
            client.plugins
                .update(plugin.class, { is_enabled })
                .then(() => this.refreshList());
        },
        doUninstall(plugin) {
            this.setConfirmationDialog(
                {
                    title: this.$__(
                        "Are you sure you want to uninstall %s?"
                    ).format(plugin.name),
                    accept_label: this.$__("Yes, uninstall"),
                    cancel_label: this.$__("No, do not uninstall"),
                },
                () => {
                    const client = APIClient.plugin_store;
                    return client.plugins
                        .remove(plugin.class)
                        .then(() => this.refreshList());
                }
            );
        },
        doUpdatePlugin(plugin) {
            const storeEntry = this.storeCatalog.find(
                p => p.class_name === plugin.class
            );
            if (!storeEntry || !storeEntry.releases?.length) {
                this.setMessage(this.$__("Update information not available."));
                return;
            }
            const mostRecent = storeEntry.releases.reduce((a, b) =>
                new Date(b.date_released) > new Date(a.date_released) ? b : a
            );
            const client = APIClient.plugin_store;
            client.plugins.create({ kpz_url: mostRecent.kpz_url }).then(() => {
                this.setMessage(this.$__("Plugin updated."));
                this.refreshList();
            });
        },
        refreshList() {
            const client = APIClient.plugin_store;
            client.plugins.getAll().then(result => {
                this.installedPlugins = result;
            });
            this.$refs.table.redraw(this.table_url());
        },
    },
    components: { KohaTable },
    name: "Home",
};
</script>
