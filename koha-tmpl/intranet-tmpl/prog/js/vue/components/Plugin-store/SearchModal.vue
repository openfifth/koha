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
import { inject } from "vue";

export default {
    name: "SearchModal",
    props: {
        installed_plugins: { type: Array, default: () => [] },
    },
    emits: ["installed"],
    setup() {
        const { setError, setMessage } = inject("mainStore");
        return { koha_version, setError, setMessage };
    },
    data() {
        return {
            storeCatalog: [],
            searchTerm: "",
        };
    },
    computed: {
        availablePlugins() {
            const installedClasses = this.installed_plugins.map(p => p.class);
            return this.storeCatalog.filter(
                p => !installedClasses.includes(p.class_name)
            );
        },
        filteredPlugins() {
            if (!this.searchTerm) return this.availablePlugins;
            const term = this.searchTerm.toLowerCase();
            return this.availablePlugins.filter(p =>
                [p.name, p.description, p.author].some(
                    field => field && field.toLowerCase().includes(term)
                )
            );
        },
    },
    beforeCreate() {
        const client = APIClient.plugin_store;
        client.plugins.getStoreAll(this.koha_version?.release).then(
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
    methods: {
        mostRecentRelease(plugin) {
            if (!plugin.releases || !plugin.releases.length) return null;
            return plugin.releases.reduce((a, b) =>
                new Date(b.date_released) > new Date(a.date_released) ? b : a
            );
        },
        install(plugin) {
            const release = this.mostRecentRelease(plugin);
            const client = APIClient.plugin_store;
            client.plugins.create({ kpz_url: release.kpz_url }).then(() => {
                this.setMessage(
                    this.$__("%s has been installed.").format(plugin.name)
                );
                this.$emit("installed");
            });
        },
    },
};
</script>
