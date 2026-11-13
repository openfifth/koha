/**
 * Client for the Display module's REST API: the displays, and the items on them.
 */
export class DisplayAPIClient {
    /**
     * @param {Function} HttpClient - The HTTP client class used to build one client per endpoint
     */
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

    /**
     * The configuration of the Display module
     * @returns {{get: function(): Promise<Object>}}
     */
    get config() {
        return {
            get: () =>
                this.httpClientDisplaysConfig.get({
                    endpoint: "",
                }),
        };
    }

    /**
     * The displays. Reading them embeds their items, libraries and item type.
     * @returns {{create: function(Object): Promise<Object>, get: function(number): Promise<Object>, getAll: function(Object=, Object=): Promise<Object[]>, update: function(Object, number): Promise<Object>, delete: function(number): Promise<*>, count: function(Object=): Promise<*>}}
     */
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

    /**
     * The items on displays, identified by the display and the item number.
     * Items can also be added to, or removed from, a display in batches by barcode.
     * @returns {{create: function(Object): Promise<Object>, get: function(number, number): Promise<Object>, getAll: function(Object=, Object=): Promise<Object[]>, update: function(Object, number, number): Promise<Object>, delete: function(number, number): Promise<*>, batchAdd: function(Object): Promise<Object>, batchDelete: function(Object): Promise<*>, count: function(Object=): Promise<*>}}
     */
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
                    // DELETE returns the raw response unless told otherwise: we need the job
                    return_response: false,
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
