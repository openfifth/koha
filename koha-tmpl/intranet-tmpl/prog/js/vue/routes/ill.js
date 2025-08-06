import { markRaw } from "vue";

import Home from "../components/ILL/Home.vue";
import ProgressRequest from "../components/ILL/ProgressRequest.vue";
import ResourceWrapper from "../components/ResourceWrapper.vue";

import { $__ } from "@koha-vue/i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/ill/ill.pl",
        is_default: true,
        is_base: true,
        title: $__("Interlibrary loans"),
        children: [
            {
                path: "",
                name: "Home",
                component: markRaw(Home),
                is_navigation_item: false,
            },
            {
                path: "/cgi-bin/koha/ill/ill-requests.pl",
                title: $__("Requesting ILLs"),
                icon: "fa fa-download",
                is_end_node: true,
            },
            {
                path: "/cgi-bin/koha/ill",
                title: $__("ISO18626"),
                icon: "fa fa-globe",
                disabled: true,
                children: [
                    {
                        path: "/cgi-bin/koha/ill/iso18626_requests",
                        title: $__("Supplying ILLs"),
                        icon: "fa fa-upload",
                        is_end_node: true,
                        resource: "ILL/SupplyingResource.vue",
                        children: [
                            {
                                path: "",
                                name: "SupplyingList",
                                component: markRaw(ResourceWrapper),
                            },
                            {
                                path: ":iso18626_request_id",
                                name: "SupplyingShow",
                                component: markRaw(ResourceWrapper),
                                title: "{iso18626_request_id}",
                            },
                            {
                                path: "progress-request/:iso18626_request_id",
                                name: "ProgressRequest",
                                component: markRaw(ProgressRequest),
                                title: $__(
                                    "Progress request {iso18626_request_id}"
                                ),
                            },
                        ],
                    },
                    {
                        path: "/cgi-bin/koha/ill/iso18626_requesting_agencies",
                        title: $__("Requesting Agencies"),
                        icon: "fa fa-building-columns",
                        is_end_node: true,
                        resource: "ILL/RequestingAgencyResource.vue",
                        children: [
                            {
                                path: "",
                                name: "RequestingAgenciesList",
                                component: markRaw(ResourceWrapper),
                            },
                            {
                                path: ":iso18626_requesting_agency_id",
                                name: "RequestingAgenciesShow",
                                component: markRaw(ResourceWrapper),
                                title: "{name}",
                            },
                            {
                                path: "add",
                                name: "RequestingAgenciesFormAdd",
                                component: markRaw(ResourceWrapper),
                                title: $__("Add requesting agency"),
                            },
                            {
                                path: "edit/:iso18626_requesting_agency_id",
                                name: "RequestingAgenciesFormAddEdit",
                                component: markRaw(ResourceWrapper),
                                title: "{name}",
                                breadcrumbFormat: ({
                                    match,
                                    params,
                                    query,
                                }) => {
                                    match.name = "RequestingAgenciesShow";
                                    return match;
                                },
                                additionalBreadcrumbs: [
                                    {
                                        title: $__("Modify requesting agency"),
                                        disabled: true,
                                    },
                                ],
                            },
                        ],
                    },
                ],
            },
        ],
    },
];
