import { markRaw } from "vue";
import { $__ } from "../i18n";

export const routes = [
    {
        path: "/cgi-bin/koha/admin/identity_providers_2.pl",
        name: "IdentityProviders2List",
        component: () =>
            import("@koha-vue/components/IdentityProviders2/List.vue"),
        title: $__("Identity Providers (New UI)"),
    },
    {
        path: "/cgi-bin/koha/admin/identity_providers_2.pl/new",
        name: "IdentityProviders2New",
        component: () =>
            import("@koha-vue/components/IdentityProviders2/Show.vue"),
        title: $__("New identity provider"),
    },
    {
        path: "/cgi-bin/koha/admin/identity_providers_2.pl/:identity_provider_id",
        name: "IdentityProviders2Show",
        component: () =>
            import("@koha-vue/components/IdentityProviders2/Show.vue"),
        title: $__("Show identity provider"),
    },
    {
        path: "/cgi-bin/koha/admin/identity_providers_2.pl/add",
        name: "IdentityProviders2FormAdd",
        component: () =>
            import("@koha-vue/components/IdentityProviders2/FormAdd.vue"),
        title: $__("New identity provider"),
    },
    {
        path: "/cgi-bin/koha/admin/identity_providers_2.pl/edit/:identity_provider_id",
        name: "IdentityProviders2FormAddEdit",
        component: () =>
            import("@koha-vue/components/IdentityProviders2/FormAddEdit.vue"),
        title: $__("Edit identity provider"),
    },
];
