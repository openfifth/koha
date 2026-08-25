function _query(params = {}) {
    const query = new URLSearchParams();
    Object.entries(params).forEach(([key, value]) => {
        if (value !== undefined && value !== null && value !== "") {
            query.append(key, value);
        }
    });
    const qs = query.toString();
    return qs ? "?" + qs : "";
}

export class CirculationAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/cgi-bin/koha/svc/",
        });
        this.restClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get checkins() {
        return {
            create: checkin =>
                this.httpClient.post({
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
                this.httpClient.post({
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
                    endpoint: "checkout_notes",
                    body: "issue_id=%s&op=%s".format(checkout_id, "cud-seen"),
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded;charset=utf-8",
                    },
                }),
            mark_as_not_seen: checkout_id =>
                this.httpClient.post({
                    endpoint: "checkout_notes",
                    body: "issue_id=%s&op=%s".format(
                        checkout_id,
                        "cud-notseen"
                    ),
                    headers: {
                        "Content-Type":
                            "application/x-www-form-urlencoded;charset=utf-8",
                    },
                }),
        };
    }

    get holdability() {
        return {
            biblio: (biblio_id, params) =>
                this.restClient.get({
                    endpoint:
                        "biblios/" +
                        biblio_id +
                        "/holdability" +
                        _query(params),
                }),
            biblioBatch: (biblio_id, body) =>
                this.restClient.post({
                    endpoint: "biblios/" + biblio_id + "/holdability/batch",
                    body,
                }),
            item: (item_id, params) =>
                this.restClient.get({
                    endpoint:
                        "items/" + item_id + "/holdability" + _query(params),
                }),
            patron: patron_id =>
                this.restClient.get({
                    endpoint: "patrons/" + patron_id + "/hold_eligibility",
                }),
            biblioItems: (biblio_id, params) =>
                this.restClient.get({
                    endpoint:
                        "biblios/" +
                        biblio_id +
                        "/items" +
                        _query({ ...params, holdability: true }),
                }),
        };
    }
}

export default CirculationAPIClient;
