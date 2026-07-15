export class CheckinAPIClient {
    constructor(HttpClient) {
        this.httpClient = new HttpClient({
            baseURL: "/api/v1/",
        });
    }

    get checkins() {
        return {
            create: (body, params = {}) =>
                this.httpClient.post({
                    endpoint:
                        "checkins" +
                        (params.confirmation
                            ? `?confirmation=${params.confirmation}`
                            : ""),
                    body,
                    headers: {
                        "x-koha-embed":
                            "item,item.biblio,checkout,hold,hold.patron,transfer,recall",
                    },
                    return_response: true,
                    mark_submitting: false,
                }),
            confirmHold: checkin_id =>
                this.httpClient.post({
                    endpoint: `checkins/${checkin_id}/hold_confirmation`,
                    headers: {
                        "x-koha-embed": "item,hold,hold.patron,transfer",
                    },
                }),
            cancelHold: (checkin_id, reason) =>
                this.httpClient.post({
                    endpoint: `checkins/${checkin_id}/hold_cancellation`,
                    body: reason ? { reason } : undefined,
                    headers: {
                        "x-koha-embed": "item,hold",
                    },
                }),
            confirmTransfer: checkin_id =>
                this.httpClient.post({
                    endpoint: `checkins/${checkin_id}/transfer_confirmation`,
                    headers: {
                        "x-koha-embed": "item,transfer,transfer.to_library",
                    },
                }),
            cancelTransfer: checkin_id =>
                this.httpClient.post({
                    endpoint: `checkins/${checkin_id}/transfer_cancellation`,
                    headers: {
                        "x-koha-embed": "item",
                    },
                }),
            confirmRecall: checkin_id =>
                this.httpClient.post({
                    endpoint: `checkins/${checkin_id}/recall_confirmation`,
                    headers: {
                        "x-koha-embed": "item,recall,recall.patron",
                    },
                }),
        };
    }
}

export default CheckinAPIClient;
