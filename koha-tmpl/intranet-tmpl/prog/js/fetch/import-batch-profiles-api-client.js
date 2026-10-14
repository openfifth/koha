export class ImportBatchProfilesAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/import_batch_profiles",
        });
    }

    get import_batch_profiles() {
        return {
            create: profile =>
                this.httpClient.post({ endpoint: "", body: profile }),
            delete: id => this.httpClient.delete({ endpoint: "/" + id }),
            update: (profile, id) =>
                this.httpClient.put({ endpoint: "/" + id, body: profile }),
            get: id => this.httpClient.get({ endpoint: "/" + id }),
            getAll: (query, params) =>
                this.httpClient.getAll({
                    endpoint: "/",
                    query,
                    params,
                    headers: {},
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default ImportBatchProfilesAPIClient;
