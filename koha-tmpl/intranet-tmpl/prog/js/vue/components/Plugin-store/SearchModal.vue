<template>
    <div class="modal show d-block" tabindex="-1">
        <div class="modal-dialog modal-lg">
            <div class="modal-content">
                <div class="modal-header">
                    <h5 class="modal-title">
                        {{ $__("Search for new plugins") }}
                    </h5>
                    <button
                        type="button"
                        class="btn-close"
                        @click="$emit('close')"
                    ></button>
                </div>
                <div class="modal-body">
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
                            <tr
                                v-for="plugin in availablePlugins"
                                :key="plugin.class_name"
                            >
                                <td>{{ plugin.name }}</td>
                                <td>{{ plugin.description }}</td>
                                <td>{{ plugin.author }}</td>
                                <td>
                                    {{
                                        mostRecentRelease(plugin)?.version ||
                                        "N/A"
                                    }}
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
                        </tbody>
                    </table>
                </div>
            </div>
        </div>
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
    emits: ["close", "installed"],
    setup() {
        const { setError, setMessage } = inject("mainStore");
        return { koha_version, setError, setMessage };
    },
    data() {
        return {
            storeCatalog: [],
        };
    },
    computed: {
        availablePlugins() {
            const installedClasses = this.installed_plugins.map(p => p.class);
            return this.storeCatalog.filter(
                p => !installedClasses.includes(p.class_name)
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
                this.$emit("close");
            });
        },
    },
};
</script>
