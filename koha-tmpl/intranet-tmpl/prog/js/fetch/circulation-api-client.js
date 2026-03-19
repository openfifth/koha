export class CirculationAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
        this.svcHttpClient = new HttpClient({
            baseURL: "/cgi-bin/koha/svc/",
        });
    }

    get checkins() {
        return {
            create: checkin =>
                this.svcHttpClient.post({
                    endpoint: "checkin",
                    body: "itemnumber=%s&borrowernumber=%s&branchcode=%s&exempt_fine=%s&op=%s".format(
                        checkin.item_id,
                        checkin.patron_id,
                        checkin.library_id,
                        checkin.exempt_fine,
                        "cud-checkin"
                    ),
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded;charset=utf-8",
                    },
                }),
        };
    }

    get checkouts() {
        return {
            renew: checkout =>
                this.svcHttpClient.post({
                    endpoint: "renew",
                    body:
                        "itemnumber=%s&borrowernumber=%s&branchcode=%s&override_limit=%s&override_debt=%s".format(
                            checkout.item_id,
                            checkout.patron_id,
                            checkout.library_id,
                            checkout.override_limit,
                            checkout.override_debt || 0
                        ) +
                        (checkout.seen !== undefined
                            ? "&seen=%s".format(checkout.seen)
                            : "") +
                        (checkout.date_due !== undefined
                            ? "&date_due=%s".format(checkout.date_due)
                            : ""),
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded;charset=utf-8",
                    },
                }),
            mark_as_seen: checkout_id =>
                this.httpClient.post({
                    endpoint: "/cgi-bin/koha/svc/checkout_notes",
                    body: "issue_id=%s&op=%s".format(checkout_id, "cud-seen"),
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded;charset=utf-8",
                    },
                }),
            mark_as_not_seen: checkout_id =>
                this.httpClient.post({
                    endpoint: "/cgi-bin/koha/svc/checkout_notes",
                    body: "issue_id=%s&op=%s".format(
                        checkout_id,
                        "cud-notseen"
                    ),
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded;charset=utf-8",
                    },
                }),
            getAll: (query, params) =>
                this.httpClient.getAll({
                    endpoint: "checkouts",
                    query,
                    params,
                }),
            count: (query = {}) =>
                this.httpClient.count({
                    endpoint:
                        "checkouts?" +
                        new URLSearchParams({
                            _page: 1,
                            _per_page: 1,
                            ...(query && { q: JSON.stringify(query) }),
                        }),
                }),
        };
    }

    get config() {
        return {
            get: () =>
                this.httpClient.get({
                    endpoint: "overdues/config",
                }),
        };
    }
}

export default CirculationAPIClient;
