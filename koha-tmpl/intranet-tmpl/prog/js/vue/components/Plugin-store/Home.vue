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
                @configure="doConfigure"
                @tool="doRunTool"
                @report="doRunReport"
                @admin="doRunAdmin"
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
import { ERROR_MESSAGES } from "./errorMessages.js";
import KohaTable from "../KohaTable.vue";

export default {
    setup() {
        const pluginStoreStore = inject("pluginStoreStore");
        const storeRefs = storeToRefs(pluginStoreStore);
        const { isUserPermitted } = pluginStoreStore;
        const {
            setMessage,
            setError,
            setConfirmationDialog,
            setComponentDialog,
        } = inject("mainStore");

        return {
            userPermissions: storeRefs.userPermissions,
            isUserPermitted,
            setMessage,
            setError,
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
                    {
                        title: "Version",
                        data: "version",
                        render: (data, type, row) => {
                            const release = this.mostRecentRelease(row);
                            if (!release || release.version === data) {
                                return data;
                            }
                            return `${data} <span class="badge text-bg-warning">Update available (${release.version})</span>`;
                        },
                    },
                    {
                        title: "Koha support",
                        data: "minimum_version",
                        render: (data, type, row) => {
                            const range = row.maximum_version
                                ? `${row.minimum_version} - ${row.maximum_version}`
                                : row.minimum_version;
                            if (this.kohaVersionSupported(row)) {
                                return range;
                            }
                            return `${range} <span class="badge text-bg-danger">Not supported</span>`;
                        },
                    },
                    {
                        title: "Status",
                        data: "is_enabled",
                        render: (data, type, row) =>
                            data
                                ? '<span class="badge text-bg-success">Enabled</span>'
                                : '<span class="badge text-bg-warning">Disabled</span>',
                    },
                ],
                url: () => this.table_url(),
                actions: this.getTableActions(),
                actions_menu: true,
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
                        configure: {
                            text: this.$__("Configure"),
                            icon: "fa fa-cog fa-fw",
                            should_display: row =>
                                row.can_configure &&
                                component.isUserPermitted(
                                    "CAN_user_plugins_configure"
                                )
                                    ? 1
                                    : 0,
                        },
                    },
                    {
                        tool: {
                            text: this.$__("Run tool"),
                            icon: "fa fa-wrench fa-fw",
                            should_display: row =>
                                row.can_tool &&
                                component.isUserPermitted(
                                    "CAN_user_plugins_tool"
                                )
                                    ? 1
                                    : 0,
                        },
                    },
                    {
                        report: {
                            text: this.$__("Run report"),
                            icon: "fa fa-table fa-fw",
                            should_display: row =>
                                row.can_report &&
                                component.isUserPermitted(
                                    "CAN_user_plugins_report"
                                )
                                    ? 1
                                    : 0,
                        },
                    },
                    {
                        admin: {
                            text: this.$__("Run admin tool"),
                            icon: "fa fa-wrench fa-fw",
                            should_display: row =>
                                row.can_admin &&
                                component.isUserPermitted(
                                    "CAN_user_plugins_admin"
                                )
                                    ? 1
                                    : 0,
                        },
                    },
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
        mostRecentRelease(row) {
            if (!this.storeCatalog) return null;
            const storeEntry = this.storeCatalog.find(
                p => p.class_name === row.class
            );
            if (!storeEntry || !storeEntry.releases?.length) return null;
            return storeEntry.releases.reduce((a, b) =>
                new Date(b.date_released) > new Date(a.date_released) ? b : a
            );
        },
        updateAvailable(row) {
            const release = this.mostRecentRelease(row);
            return !!release && release.version !== row.version;
        },
        compareVersions(a, b) {
            const pa = a.split(".").map(Number);
            const pb = b.split(".").map(Number);
            for (let i = 0; i < Math.max(pa.length, pb.length); i++) {
                const diff = (pa[i] || 0) - (pb[i] || 0);
                if (diff) return diff;
            }
            return 0;
        },
        kohaVersionSupported(row) {
            const current = koha_version.maintenance;
            if (
                row.minimum_version &&
                this.compareVersions(current, row.minimum_version) < 0
            ) {
                return false;
            }
            if (
                row.maximum_version &&
                this.compareVersions(current, row.maximum_version) > 0
            ) {
                return false;
            }
            return true;
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
        runPlugin(plugin, method) {
            window.location.href =
                "/cgi-bin/koha/plugins/run.pl?class=" +
                encodeURIComponent(plugin.class) +
                "&method=" +
                method;
        },
        doConfigure(plugin) {
            this.runPlugin(plugin, "configure");
        },
        doRunTool(plugin) {
            this.runPlugin(plugin, "tool");
        },
        doRunReport(plugin) {
            this.runPlugin(plugin, "report");
        },
        doRunAdmin(plugin) {
            this.runPlugin(plugin, "admin");
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
        doUpdatePlugin(plugin, confirmUnsigned = false) {
            const release = this.mostRecentRelease(plugin);
            if (!release) {
                this.setMessage(this.$__("Update information not available."));
                return;
            }
            const client = APIClient.plugin_store;
            client.plugins
                .create({
                    kpz_url: release.kpz_url,
                    ...(confirmUnsigned ? { confirm_unsigned: true } : {}),
                })
                .then(
                    () => {
                        this.setMessage(this.$__("Plugin updated."));
                        this.refreshList();
                    },
                    error => {
                        if (error.message === "UNSIGNEDCONFIRMREQUIRED") {
                            this.setConfirmationDialog(
                                {
                                    title: this.$__(
                                        "This plugin isn't signed by the plugin store. It may be a private/in-house plugin the store has never seen, or one published before this store supported signing. Update anyway?"
                                    ),
                                    accept_label:
                                        this.$__("Yes, update anyway"),
                                    cancel_label: this.$__("No, cancel"),
                                },
                                () => this.doUpdatePlugin(plugin, true)
                            );
                            return;
                        }
                        this.setError(
                            this.$__(
                                ERROR_MESSAGES[error.message] ||
                                    "An unknown error has occurred."
                            )
                        );
                    }
                );
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
