<template>
    <div>
        <div class="mb-3">
            <input
                type="text"
                class="form-control"
                v-model="searchTerm"
                :placeholder="$__('Search by name, description, or author')"
            />
        </div>
        <table class="table table-striped">
            <thead>
                <tr>
                    <th>{{ $__("Name") }}</th>
                    <th>{{ $__("Description") }}</th>
                    <th>{{ $__("Author") }}</th>
                    <th>{{ $__("Latest release") }}</th>
                    <th></th>
                </tr>
            </thead>
            <tbody>
                <tr v-for="plugin in filteredPlugins" :key="plugin.class_name">
                    <td>{{ plugin.name }}</td>
                    <td>{{ plugin.description }}</td>
                    <td>{{ plugin.author }}</td>
                    <td>
                        {{ mostRecentRelease(plugin)?.version || "N/A" }}
                    </td>
                    <td>
                        <button
                            class="btn btn-default btn-sm"
                            :disabled="!mostRecentRelease(plugin)"
                            @click="install(plugin)"
                        >
                            <i class="fa fa-download"></i>
                            {{ $__("Install") }}
                        </button>
                    </td>
                </tr>
                <tr v-if="!filteredPlugins.length">
                    <td colspan="5">{{ $__("No plugins found") }}</td>
                </tr>
            </tbody>
        </table>
    </div>
</template>

<script>
import { APIClient } from "../../fetch/api-client.js";
import { ERROR_MESSAGES } from "./errorMessages.js";
import { inject } from "vue";

export default {
    name: "SearchModal",
    props: {
        installed_plugins: { type: Array, default: () => [] },
    },
    emits: ["installed"],
    setup() {
        const { setError, setMessage, setConfirmationDialog } =
            inject("mainStore");
        return { koha_version, setError, setMessage, setConfirmationDialog };
    },
    data() {
        return {
            storeCatalog: [],
            searchTerm: "",
            searchDebounceTimer: null,
        };
    },
    computed: {
        filteredPlugins() {
            const installedClasses = this.installed_plugins.map(p => p.class);
            return this.storeCatalog.filter(
                p => !installedClasses.includes(p.class_name)
            );
        },
    },
    watch: {
        searchTerm() {
            clearTimeout(this.searchDebounceTimer);
            this.searchDebounceTimer = setTimeout(
                () => this.fetchCatalog(),
                300
            );
        },
    },
    beforeCreate() {
        this.fetchCatalog();
    },
    methods: {
        fetchCatalog() {
            const client = APIClient.plugin_store;
            client.plugins
                .getStoreAll(this.koha_version?.release, this.searchTerm)
                .then(
                    result => {
                        this.storeCatalog = result;
                    },
                    () => {
                        this.setError(
                            this.$__(
                                "The plugin store could not be reached. Please check your internet connection and try again."
                            )
                        );
                    }
                );
        },
        mostRecentRelease(plugin) {
            if (!plugin.releases || !plugin.releases.length) return null;
            return plugin.releases.reduce((a, b) =>
                new Date(b.date_released) > new Date(a.date_released) ? b : a
            );
        },
        install(plugin, confirmUnsigned = false) {
            const release = this.mostRecentRelease(plugin);
            const client = APIClient.plugin_store;
            client.plugins
                .create({
                    kpz_url: release.kpz_url,
                    ...(confirmUnsigned ? { confirm_unsigned: true } : {}),
                })
                .then(
                    () => {
                        this.setMessage(
                            this.$__("%s has been installed.").format(
                                plugin.name
                            )
                        );
                        this.$emit("installed");
                    },
                    error => {
                        if (error.message === "UNSIGNEDCONFIRMREQUIRED") {
                            this.setConfirmationDialog(
                                {
                                    title: this.$__(
                                        "This plugin isn't signed by the plugin store. It may be a private/in-house plugin the store has never seen, or one published before this store supported signing. Install anyway?"
                                    ),
                                    accept_label: this.$__(
                                        "Yes, install anyway"
                                    ),
                                    cancel_label: this.$__("No, cancel"),
                                },
                                () => this.install(plugin, true)
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
    },
};
</script>
