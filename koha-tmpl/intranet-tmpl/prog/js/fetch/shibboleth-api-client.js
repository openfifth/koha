export class ShibbolethAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/shibboleth/",
        });
    }

    get config() {
        return {
            get: () =>
                this.httpClient.get({
                    endpoint: "config",
                }),
            update: config =>
                this.httpClient.put({
                    endpoint: "config",
                    body: config,
                }),
        };
    }

    get mappings() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: "mappings/" + id,
                }),
            getAll: params =>
                this.httpClient.getAll({
                    endpoint: "mappings",
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "mappings/" + id,
                }),
            create: mapping =>
                this.httpClient.post({
                    endpoint: "mappings",
                    body: mapping,
                }),
            update: (mapping, id) =>
                this.httpClient.put({
                    endpoint: "mappings/" + id,
                    body: mapping,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "mappings?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default ShibbolethAPIClient;
