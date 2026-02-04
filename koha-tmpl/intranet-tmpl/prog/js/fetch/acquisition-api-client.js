export class AcquisitionAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/acquisitions/",
        });
    }

    get config() {
        return {
            get: moduleEndpoint =>
                this.httpClient.get({
                    endpoint: moduleEndpoint + "/config",
                }),
        };
    }

    get vendors() {
        return {
            get: id =>
                this.httpClient.get({
                    endpoint: "vendors/" + id,
                    headers: {
                        "x-koha-embed":
                            "aliases,subscriptions+count,interfaces,contacts,contracts,baskets+count,invoices+count,extended_attributes,+strings",
                    },
                }),
            getAll: (query, params) =>
                this.httpClient.getAll({
                    endpoint: "vendors",
                    query,
                    params: { _order_by: "name", ...params },
                    headers: {
                        "x-koha-embed": "aliases,baskets+count",
                    },
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "vendors/" + id,
                }),
            create: vendor =>
                this.httpClient.post({
                    endpoint: "vendors",
                    body: vendor,
                }),
            update: (vendor, id) =>
                this.httpClient.put({
                    endpoint: "vendors/" + id,
                    body: vendor,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "vendors?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get baskets() {
        return {
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "baskets?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get additional_fields() {
        return {
            getAll: resource_type =>
                this.httpClient.getAll({
                    endpoint: "extended_attribute_types",
                    params: { resource_type },
                }),
        };
    }

    get fiscalPeriods() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "fiscal_periods/" + id,
                    headers: {
                        "x-koha-embed":
                            "owner,managing_library,managing_library.acquisitions_library_groups,ledgers",
                        ...headers,
                    },
                }),
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "fiscal_periods",
                    query,
                    params,
                    headers: {
                        "x-koha-embed": "ledgers",
                        ...headers,
                    },
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "fiscal_periods/" + id,
                }),
            create: fiscal_period =>
                this.httpClient.post({
                    endpoint: "fiscal_periods",
                    body: fiscal_period,
                }),
            update: (fiscal_period, id) =>
                this.httpClient.put({
                    endpoint: "fiscal_periods/" + id,
                    body: fiscal_period,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "fiscal_periods?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get ledgers() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "ledgers/" + id,
                    headers: {
                        "x-koha-embed":
                            "owner,managing_library,managing_library.acquisitions_library_groups,fiscal_period,funds",
                        ...headers,
                    },
                }),
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "ledgers",
                    query,
                    params,
                    ...(headers && {
                        headers,
                    }),
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "ledgers/" + id,
                }),
            create: ledger =>
                this.httpClient.post({
                    endpoint: "ledgers",
                    body: ledger,
                }),
            update: (ledger, id) =>
                this.httpClient.put({
                    endpoint: "ledgers/" + id,
                    body: ledger,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "ledgers?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get funds() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "funds/" + id,
                    headers: {
                        "x-koha-embed":
                            "owner,managing_library,fiscal_period,fund_group,ledger,fund_allocations,sub_funds,parent_fund",
                        ...headers,
                    },
                }),
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "funds",
                    query,
                    params,
                    ...(headers && {
                        headers,
                    }),
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "funds/" + id,
                }),
            create: fund =>
                this.httpClient.post({
                    endpoint: "funds",
                    body: fund,
                }),
            update: (fund, id) =>
                this.httpClient.put({
                    endpoint: "funds/" + id,
                    body: fund,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "funds?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
            getFundGroup: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "fund_groups",
                    query,
                    params,
                    ...(headers && {
                        headers,
                    }),
                }),
        };
    }

    get fundAllocations() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "fund_allocations/" + id,
                    ...(headers && {
                        headers,
                    }),
                }),
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "fund_allocations",
                    query,
                    params,
                    ...(headers && {
                        headers,
                    }),
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "fund_allocations/" + id,
                }),
            create: fund_allocation =>
                this.httpClient.post({
                    endpoint: "fund_allocations",
                    body: fund_allocation,
                }),
            transfer: fund_allocation =>
                this.httpClient.post({
                    endpoint: "fund_allocations/transfer",
                    body: fund_allocation,
                }),
            update: (fund_allocation, id) =>
                this.httpClient.put({
                    endpoint: "fund_allocations/" + id,
                    body: fund_allocation,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "fund_allocations?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get fundGroups() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "fund_groups/" + id,
                    ...(headers && {
                        headers,
                    }),
                }),
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "fund_groups",
                    query,
                    params,
                    ...(headers && {
                        headers,
                    }),
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "fund_groups/" + id,
                }),
            create: fund_group =>
                this.httpClient.post({
                    endpoint: "fund_groups",
                    body: fund_group,
                }),
            update: (fund_group, id) =>
                this.httpClient.put({
                    endpoint: "fund_groups/" + id,
                    body: fund_group,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "fund_groups?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get orderlines() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "orderlines/" + id,
                    headers: {
                        "x-koha-embed":
                            "extended_attributes,+strings,vendor,managing_library,biblio",
                        ...headers,
                    },
                }),
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "orderlines",
                    query,
                    params,
                    ...(headers && {
                        headers,
                    }),
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "orderlines/" + id,
                }),
            create: orderline =>
                this.httpClient.post({
                    endpoint: "orderlines",
                    body: orderline,
                }),
            update: (orderline, id) =>
                this.httpClient.put({
                    endpoint: "orderlines/" + id,
                    body: orderline,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "orderlines?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }
}

export default AcquisitionAPIClient;
