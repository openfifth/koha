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

import App from "../components/IdentityProviders/Main.vue";

import { routes as routesDef } from "../routes/identity-providers";

import { useMainStore } from "../stores/main";
import { useIdentityProvidersStore } from "../stores/identity-providers";
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
const IdentityProvidersStore = useIdentityProvidersStore(pinia);
app.provide("IdentityProvidersStore", IdentityProvidersStore);

app.mount("#identity-providers");

const { removeMessages } = mainStore;
router.beforeEach((to, from) => {
    navigationStore.$patch({ current: to.matched, params: to.params || {} });
    removeMessages();
});
