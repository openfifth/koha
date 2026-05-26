export class DisplayAPIClient {
    constructor(HttpClient) {
        this.httpClientDisplaysConfig = new HttpClient({
            baseURL: "/api/v1/displays/config/",
        });

        this.httpClientDisplays = new HttpClient({
            baseURL: "/api/v1/displays/",
        });

        this.httpClientDisplayItems = new HttpClient({
            baseURL: "/api/v1/display/items/",
        });
    }

    get config() {
        return {
            get: () =>
                this.httpClientDisplaysConfig.get({
                    endpoint: "",
                }),
        };
    }

    get displays() {
        return {
            create: display =>
                this.httpClientDisplays.post({
                    endpoint: "",
                    body: display,
                }),
            get: id =>
                this.httpClientDisplays.get({
                    endpoint: "" + id,
                    headers: {
                        "x-koha-embed":
                            "display_items,display_library,home_library,holding_library,item_type,+strings",
                    },
                }),
            getAll: (query, params) =>
                this.httpClientDisplays.getAll({
                    endpoint: "",
                    headers: {
                        "x-koha-embed":
                            "display_items,display_library,home_library,holding_library,+strings",
                    },
                    params,
                    query,
                }),
            update: (display, id) =>
                this.httpClientDisplays.put({
                    endpoint: "" + id,
                    body: display,
                }),
            delete: id =>
                this.httpClientDisplays.delete({
                    endpoint: "" + id,
                }),
            count: (query = {}) =>
                this.httpClientDisplays.count({
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

    get displayItems() {
        return {
            create: displayItem =>
                this.httpClientDisplayItems.post({
                    endpoint: "",
                    body: displayItem,
                }),
            get: (display_id, itemnumber) =>
                this.httpClientDisplayItems.get({
                    endpoint: "" + display_id + "/" + itemnumber,
                }),
            getAll: (query, params) =>
                this.httpClientDisplayItems.getAll({
                    endpoint: "",
                    query,
                    params,
                }),
            update: (displayItem, display_id, itemnumber) =>
                this.httpClientDisplayItems.put({
                    endpoint: "" + display_id + "/" + itemnumber,
                    body: displayItem,
                }),
            delete: (display_id, itemnumber) =>
                this.httpClientDisplayItems.delete({
                    endpoint: "" + display_id + "/" + itemnumber,
                }),
            batchAdd: displayItems =>
                this.httpClientDisplayItems.post({
                    endpoint: "batch",
                    body: displayItems,
                }),
            batchDelete: displayItems =>
                this.httpClientDisplayItems.delete({
                    endpoint: "batch",
                    body: displayItems,
                    parseResponse: true,
                }),
            count: (query = {}) =>
                this.httpClientDisplayItems.count({
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

export default DisplayAPIClient;
