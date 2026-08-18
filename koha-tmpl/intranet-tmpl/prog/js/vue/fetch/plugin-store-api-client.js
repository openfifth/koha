import HttpClient from "./http-client";

export class PluginStoreAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "",
        });
    }

    get plugins() {
        return {
            getStoreAll: (koha_version, q) =>
                this.getAll({
                    endpoint: `${plugin_store_url}/api/v1/plugins`,
                    params: {
                        koha_version: koha_version || "",
                        ...(q ? { q } : {}),
                        _per_page: 100,
                    },
                }),
            getAll: () =>
                this.getAll({
                    endpoint: "/api/v1/plugins",
                }),
            getConfig: () =>
                this.get({
                    endpoint: "/api/v1/plugins/config",
                }),
            create: plugin =>
                this.post({
                    endpoint: "/api/v1/plugins",
                    body: plugin,
                }),
            upload: formData =>
                this.postForm({
                    endpoint: "/api/v1/plugins/upload",
                    body: formData,
                }),
            update: (plugin_class, body) =>
                this.put({
                    endpoint: `/api/v1/plugins/${encodeURIComponent(plugin_class)}`,
                    body,
                }),
            remove: plugin_class =>
                this.delete({
                    endpoint: `/api/v1/plugins/${encodeURIComponent(plugin_class)}`,
                }),
        };
    }
}

export default PluginStoreAPIClient;
