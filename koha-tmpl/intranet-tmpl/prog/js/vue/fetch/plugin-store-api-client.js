import HttpClient from "./http-client";

export class PluginStoreAPIClient extends HttpClient {
    constructor() {
        super({
            baseURL: "",
        });
    }

    get plugins() {
        return {
            getStoreAll: koha_version_release =>
                this.getAll({
                    endpoint: `${plugin_store_url}/api/plugins`,
                    params: {
                        koha_version_release: koha_version_release
                            ? koha_version_release
                            : "",
                    },
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
        };
    }
}

export default PluginStoreAPIClient;
