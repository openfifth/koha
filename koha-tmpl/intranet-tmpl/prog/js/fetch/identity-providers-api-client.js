export class IdentityProvidersAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/auth/identity_providers",
        });
        this.allHostnamesHttpClient = new HttpClient({
            baseURL: "/api/v1/auth/hostnames",
        });
    }

    get providers() {
        return {
            getAll: params =>
                this.httpClient.getAll({
                    endpoint: "/",
                    params,
                }),
            get: id =>
                this.httpClient.get({
                    endpoint: "/" + id,
                    headers: {
                        "x-koha-embed": "domains,hostnames,mappings",
                    },
                }),
            create: provider =>
                this.httpClient.post({
                    endpoint: "/",
                    body: provider,
                }),
            update: (provider, id) =>
                this.httpClient.put({
                    endpoint: "/" + id,
                    body: provider,
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "/" + id,
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
                    endpoint: `/${providerId}/mappings`,
                    params,
                }),
            get: (providerId, mappingId) =>
                this.httpClient.get({
                    endpoint: `/${providerId}/mappings/${mappingId}`,
                }),
            create: (providerId, mapping) =>
                this.httpClient.post({
                    endpoint: `/${providerId}/mappings`,
                    body: mapping,
                }),
            update: (providerId, mapping, mappingId) =>
                this.httpClient.put({
                    endpoint: `/${providerId}/mappings/${mappingId}`,
                    body: mapping,
                }),
            delete: (providerId, mappingId) =>
                this.httpClient.delete({
                    endpoint: `/${providerId}/mappings/${mappingId}`,
                }),
            count: (providerId, query = {}) =>
                this.httpClient.count({
                    endpoint:
                        `/${providerId}/mappings?` +
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
            getAll: (providerId, params) =>
                this.httpClient.getAll({
                    endpoint: `/${providerId}/hostnames`,
                    params,
                }),
            get: (providerId, hostnameId) =>
                this.httpClient.get({
                    endpoint: `/${providerId}/hostnames/${hostnameId}`,
                }),
            create: (providerId, hostname) =>
                this.httpClient.post({
                    endpoint: `/${providerId}/hostnames`,
                    body: hostname,
                }),
            update: (providerId, hostname, hostnameId) =>
                this.httpClient.put({
                    endpoint: `/${providerId}/hostnames/${hostnameId}`,
                    body: hostname,
                }),
            delete: (providerId, hostnameId) =>
                this.httpClient.delete({
                    endpoint: `/${providerId}/hostnames/${hostnameId}`,
                }),
        };
    }

    get saml2() {
        return {
            generateCertificate: options =>
                this.httpClient.post({
                    endpoint: "/saml2/certificate",
                    body: options,
                }),
        };
    }

    get allHostnames() {
        return {
            getAll: params =>
                this.allHostnamesHttpClient.getAll({
                    endpoint: "/",
                    params,
                }),
            get: id =>
                this.allHostnamesHttpClient.get({
                    endpoint: "/" + id,
                }),
        };
    }

    get domains() {
        return {
            getAll: (providerId, params) =>
                this.httpClient.getAll({
                    endpoint: `/${providerId}/domains`,
                    params,
                }),
            get: (providerId, domainId) =>
                this.httpClient.get({
                    endpoint: `/${providerId}/domains/${domainId}`,
                }),
            create: (providerId, domain) =>
                this.httpClient.post({
                    endpoint: `/${providerId}/domains`,
                    body: domain,
                }),
            update: (providerId, domain, domainId) =>
                this.httpClient.put({
                    endpoint: `/${providerId}/domains/${domainId}`,
                    body: domain,
                }),
            delete: (providerId, domainId) =>
                this.httpClient.delete({
                    endpoint: `/${providerId}/domains/${domainId}`,
                }),
            count: (providerId, query = {}) =>
                this.httpClient.count({
                    endpoint:
                        `/${providerId}/domains?` +
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
