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
                            "owner,managing_library,managing_library.acquisitions_library_groups,ledgers,child_object_managing_branches",
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
                            "owner,managing_library,managing_library.acquisitions_library_groups,fiscal_period.managing_library.acquisitions_library_groups,funds,funds.managing_library,allocations,child_object_managing_branches",
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
                            "owner,managing_library,fiscal_period,ledger,ledger.managing_library,ledger.managing_library.acquisitions_library_groups,managing_library.acquisitions_library_groups,allocations,sub_funds,parent_fund,parent_fund.managing_library.acquisitions_library_groups,child_object_managing_branches",
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
        };
    }

    get allocations() {
        return {
            get: (id, headers) =>
                this.httpClient.get({
                    endpoint: "allocations/" + id,
                    ...(headers && {
                        headers,
                    }),
                }),
            getAll: (query, params, headers) =>
                this.httpClient.getAll({
                    endpoint: "allocations",
                    query,
                    params,
                    ...(headers && {
                        headers,
                    }),
                }),
            delete: id =>
                this.httpClient.delete({
                    endpoint: "allocations/" + id,
                }),
            create: allocation =>
                this.httpClient.post({
                    endpoint: "allocations",
                    body: allocation,
                }),
            transfer: allocation =>
                this.httpClient.post({
                    endpoint: "allocations/transfer",
                    body: allocation,
                }),
            update: (allocation, id) =>
                this.httpClient.put({
                    endpoint: "allocations/" + id,
                    body: allocation,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "allocations?" +
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
                            "extended_attributes,+strings,vendor,managing_library,biblio,managed_by.patron,patrons_to_notify.patron",
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
            create: (orderline, headers) =>
                this.httpClient.post({
                    endpoint: "orderlines",
                    body: orderline,
                    headers,
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
