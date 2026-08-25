import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";

import { config, library } from "@fortawesome/fontawesome-svg-core";
config.autoAddCss = false;
import "@fortawesome/fontawesome-svg-core/styles.css";
import {
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import vSelect from "vue-select";

library.add(faPlus, faMinus, faPencil, faTrash, faSpinner);

import App from "../../components/Circulation/Holds/Main.vue";

import "../../../../css/vue.css";

import { routes as routesDef } from "../../routes/circulation/holds";

import { useMainStore } from "../../stores/main";
import { useHoldsStore } from "../../stores/holds";
import { useNavigationStore } from "../../stores/navigation";
import i18n from "@koha-vue/i18n";

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
app.provide("holdsStore", useHoldsStore(pinia));

app.mount("#holds");

const { removeMessages } = mainStore;
router.beforeEach((to, from) => {
    navigationStore.$patch({
        current: to.matched,
        params: to.params || {},
        query: to.query || {},
        from,
    });
    removeMessages(); // This will actually flag the messages as displayed already
});
