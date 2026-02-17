import { markRaw } from "vue";

import Home from "../components/IdentityProviders/Home.vue";
import ResourceWrapper from "../components/ResourceWrapper.vue";
import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/admin/identity_providers.pl",
        is_default: true,
        is_base: true,
        title: $__("Identity providers"),
        children: [
            {
                path: "",
                name: "IdentityProvidersHome",
                component: markRaw(Home),
                is_navigation_item: false,
            },
            {
                path: "/cgi-bin/koha/admin/identity_providers",
                title: $__("Providers"),
                icon: "fa fa-id-card",
                is_end_node: true,
                resource: "IdentityProviders/ProviderResource.vue",
                children: [
                    {
                        path: "",
                        name: "ProvidersList",
                        component: markRaw(ResourceWrapper),
                        title: $__("Identity providers"),
                    },
                    {
                        path: ":identity_provider_id",
                        name: "ProviderShow",
                        component: markRaw(ResourceWrapper),
                        title: $__("Show provider"),
                    },
                    {
                        path: "add",
                        name: "ProviderFormAdd",
                        component: markRaw(ResourceWrapper),
                        title: $__("New identity provider"),
                    },
                    {
                        path: "edit/:identity_provider_id",
                        name: "ProviderFormEdit",
                        component: markRaw(ResourceWrapper),
                        title: $__("Edit identity provider"),
                    },
                    {
                        path: ":identity_provider_id/mappings",
                        title: $__("Field mappings"),
                        icon: "fa fa-exchange-alt",
                        is_end_node: true,
                        resource: "IdentityProviders/MappingResource.vue",
                        children: [
                            {
                                path: "",
                                name: "MappingsList",
                                component: markRaw(ResourceWrapper),
                                title: $__("Field mappings"),
                            },
                            {
                                path: ":identity_provider_mapping_id",
                                name: "MappingShow",
                                component: markRaw(ResourceWrapper),
                                title: $__("Show mapping"),
                            },
                            {
                                path: "add",
                                name: "MappingsFormAdd",
                                component: markRaw(ResourceWrapper),
                                title: $__("New field mapping"),
                            },
                            {
                                path: "edit/:identity_provider_mapping_id",
                                name: "MappingsFormEdit",
                                component: markRaw(ResourceWrapper),
                                title: $__("Edit field mapping"),
                            },
                        ],
                    },
                    {
                        path: ":identity_provider_id/domains",
                        title: $__("Domains"),
                        icon: "fa fa-globe",
                        is_end_node: true,
                        resource: "IdentityProviders/DomainResource.vue",
                        children: [
                            {
                                path: "",
                                name: "DomainsList",
                                component: markRaw(ResourceWrapper),
                                title: $__("Domains"),
                            },
                            {
                                path: ":identity_provider_domain_id",
                                name: "DomainShow",
                                component: markRaw(ResourceWrapper),
                                title: $__("Show domain"),
                            },
                            {
                                path: "add",
                                name: "DomainsFormAdd",
                                component: markRaw(ResourceWrapper),
                                title: $__("New domain"),
                            },
                            {
                                path: "edit/:identity_provider_domain_id",
                                name: "DomainsFormEdit",
                                component: markRaw(ResourceWrapper),
                                title: $__("Edit domain"),
                            },
                        ],
                    },
                ],
            },
        ],
    },
];
