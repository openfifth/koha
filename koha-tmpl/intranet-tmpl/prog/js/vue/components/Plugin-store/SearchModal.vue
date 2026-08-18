<template>
    <div>
        <div class="row mb-3">
            <div class="col-md-8">
                <input
                    type="text"
                    class="form-control"
                    v-model="searchTerm"
                    :placeholder="$__('Search by name, description, or author')"
                />
            </div>
            <div class="col-md-4" v-if="hasSearched">
                <select
                    v-model="sortOrder"
                    class="form-select"
                    @change="changeSort"
                >
                    <option value="name">{{ $__("Name (A-Z)") }}</option>
                    <option value="-name">{{ $__("Name (Z-A)") }}</option>
                    <option value="author">{{ $__("Author (A-Z)") }}</option>
                    <option value="-author">{{ $__("Author (Z-A)") }}</option>
                    <option value="-updated">
                        {{ $__("Recently updated") }}
                    </option>
                    <option value="updated">
                        {{ $__("Least recently updated") }}
                    </option>
                </select>
            </div>
        </div>

        <p v-if="!hasSearched" class="text-muted">
            {{ $__("Type to search for plugins") }}
        </p>

        <template v-else>
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
                        v-for="plugin in filteredPlugins"
                        :key="plugin.class_name"
                    >
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

            <div
                class="d-flex justify-content-between align-items-center"
                v-if="totalCount"
            >
                <span>
                    {{
                        $__("Showing %s-%s of %s").format(
                            resultRangeStart,
                            resultRangeEnd,
                            totalCount
                        )
                    }}
                </span>
                <nav>
                    <ul class="pagination mb-0">
                        <li
                            class="page-item"
                            :class="{ disabled: currentPage === 1 }"
                        >
                            <button
                                class="page-link"
                                @click="goToPage(currentPage - 1)"
                            >
                                {{ $__("Previous") }}
                            </button>
                        </li>
                        <li
                            class="page-item"
                            v-for="page in totalPages"
                            :key="page"
                            :class="{ active: page === currentPage }"
                        >
                            <button class="page-link" @click="goToPage(page)">
                                {{ page }}
                            </button>
                        </li>
                        <li
                            class="page-item"
                            :class="{ disabled: currentPage === totalPages }"
                        >
                            <button
                                class="page-link"
                                @click="goToPage(currentPage + 1)"
                            >
                                {{ $__("Next") }}
                            </button>
                        </li>
                    </ul>
                </nav>
            </div>
        </template>
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
            hasSearched: false,
            currentPage: 1,
            perPage: 20,
            totalCount: 0,
            sortOrder: "name",
        };
    },
    computed: {
        filteredPlugins() {
            const installedClasses = this.installed_plugins.map(p => p.class);
            return this.storeCatalog.filter(
                p => !installedClasses.includes(p.class_name)
            );
        },
        totalPages() {
            return Math.max(1, Math.ceil(this.totalCount / this.perPage));
        },
        resultRangeStart() {
            return this.totalCount === 0
                ? 0
                : (this.currentPage - 1) * this.perPage + 1;
        },
        resultRangeEnd() {
            return Math.min(this.currentPage * this.perPage, this.totalCount);
        },
    },
    watch: {
        searchTerm(newTerm) {
            clearTimeout(this.searchDebounceTimer);
            if (!newTerm) {
                this.hasSearched = false;
                this.storeCatalog = [];
                this.totalCount = 0;
                return;
            }
            this.searchDebounceTimer = setTimeout(() => {
                this.currentPage = 1;
                this.fetchCatalog();
            }, 300);
        },
    },
    methods: {
        fetchCatalog() {
            this.hasSearched = true;
            const client = APIClient.plugin_store;
            client.plugins
                .getStoreAll(this.koha_version?.release, {
                    q: this.searchTerm,
                    page: this.currentPage,
                    orderBy: this.sortOrder,
                })
                .then(
                    response => {
                        this.totalCount = parseInt(
                            response.headers.get("X-Total-Count") || "0",
                            10
                        );
                        return response.json();
                    },
                    () => {
                        this.setError(
                            this.$__(
                                "The plugin store could not be reached. Please check your internet connection and try again."
                            )
                        );
                    }
                )
                .then(result => {
                    if (result) this.storeCatalog = result;
                })
                .catch(() => {
                    this.setError(
                        this.$__(
                            "The plugin store could not be reached. Please check your internet connection and try again."
                        )
                    );
                });
        },
        changeSort() {
            this.currentPage = 1;
            this.fetchCatalog();
        },
        goToPage(page) {
            if (page < 1 || page > this.totalPages || page === this.currentPage)
                return;
            this.currentPage = page;
            this.fetchCatalog();
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
