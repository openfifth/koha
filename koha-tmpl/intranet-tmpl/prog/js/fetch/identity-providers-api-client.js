export class IdentityProvidersAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/auth/identity_providers/",
        });
        this.hostnamesHttpClient = new HttpClient({
            baseURL: "/api/v1/auth/identity_provider_hostnames/",
        });
        this.allHostnamesHttpClient = new HttpClient({
            baseURL: "/api/v1/auth/hostnames/",
        });
    }

    get providers() {
        return {
            getAll: params =>
                this.httpClient.getAll({
                    endpoint: "",
                    params,
                }),
            get: id =>
                this.httpClient.get({
                    endpoint: id,
                }),
            create: provider =>
                this.httpClient.post({
                    endpoint: "",
                    body: provider,
                }),
            update: (provider, id) =>
                this.httpClient.put({
                    endpoint: id,
                    body: provider,
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: id,
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

    get mappings() {
        return {
            getAll: (providerId, params) =>
                this.httpClient.getAll({
                    endpoint: `${providerId}/mappings`,
                    params,
                }),
            get: (providerId, mappingId) =>
                this.httpClient.get({
                    endpoint: `${providerId}/mappings/${mappingId}`,
                }),
            create: (providerId, mapping) =>
                this.httpClient.post({
                    endpoint: `${providerId}/mappings`,
                    body: mapping,
                }),
            update: (providerId, mapping, mappingId) =>
                this.httpClient.put({
                    endpoint: `${providerId}/mappings/${mappingId}`,
                    body: mapping,
                }),
            delete: (providerId, mappingId) =>
                this.httpClient.delete({
                    endpoint: `${providerId}/mappings/${mappingId}`,
                }),
            count: (providerId, query = {}) =>
                this.httpClient.count({
                    endpoint:
                        `${providerId}/mappings?` +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get hostnames() {
        return {
            getAll: params =>
                this.hostnamesHttpClient.getAll({
                    endpoint: "",
                    params,
                }),
            get: id =>
                this.hostnamesHttpClient.get({
                    endpoint: id,
                }),
            create: hostname =>
                this.hostnamesHttpClient.post({
                    endpoint: "",
                    body: hostname,
                }),
            update: (hostname, id) =>
                this.hostnamesHttpClient.put({
                    endpoint: id,
                    body: hostname,
                }),
            delete: id =>
                this.hostnamesHttpClient.delete({
                    endpoint: id,
                }),
        };
    }

    get allHostnames() {
        return {
            getAll: params =>
                this.allHostnamesHttpClient.getAll({
                    endpoint: "",
                    params,
                }),
            get: id =>
                this.allHostnamesHttpClient.get({
                    endpoint: id,
                }),
        };
    }

    get domains() {
        return {
            getAll: (providerId, params) =>
                this.httpClient.getAll({
                    endpoint: `${providerId}/domains`,
                    params,
                }),
            get: (providerId, domainId) =>
                this.httpClient.get({
                    endpoint: `${providerId}/domains/${domainId}`,
                }),
            create: (providerId, domain) =>
                this.httpClient.post({
                    endpoint: `${providerId}/domains`,
                    body: domain,
                }),
            update: (providerId, domain, domainId) =>
                this.httpClient.put({
                    endpoint: `${providerId}/domains/${domainId}`,
                    body: domain,
                }),
            delete: (providerId, domainId) =>
                this.httpClient.delete({
                    endpoint: `${providerId}/domains/${domainId}`,
                }),
            count: (providerId, query = {}) =>
                this.httpClient.count({
                    endpoint:
                        `${providerId}/domains?` +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default IdentityProvidersAPIClient;
