import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";

import { library } from "@fortawesome/fontawesome-svg-core";
import {
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faSave,
    faCog,
    faExchangeAlt,
    faIdCard,
    faGlobe,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import vSelect from "vue-select";

library.add(
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faSave,
    faCog,
    faExchangeAlt,
    faIdCard,
    faGlobe
);

import App from "../components/IdentityProviders2/Main.vue"; // POINTING TO THE NEW MAIN.VUE

import { routes as routesDef } from "../routes/identity-providers-2"; // POINTING TO THE NEW ROUTES FILE

import { useMainStore } from "../stores/main";
import { useNavigationStore } from "../stores/navigation";
import i18n from "../i18n";

const pinia = createPinia();

const mainStore = useMainStore(pinia);
const navigationStore = useNavigationStore(pinia);
const routes = navigationStore.setRoutes(routesDef);

const router = createRouter({
    history: createWebHistory(),
    linkActiveClass: "current",
    routes,
});

const app = createApp(App);

const rootComponent = app
    .use(i18n)
    .use(pinia)
    .use(router)
    .component("font-awesome-icon", FontAwesomeIcon)
    .component("v-select", vSelect);

app.config.unwrapInjectedRef = true;
app.provide("mainStore", mainStore);
app.provide("navigationStore", navigationStore);
// Assuming a new store for IdP2 if needed, otherwise use a generic one
// const IdentityProviders2Store = useIdentityProviders2Store(pinia);
// app.provide("IdentityProviders2Store", IdentityProviders2Store);

app.mount("#identity-providers-2"); // MOUNTING TO A NEW ID
