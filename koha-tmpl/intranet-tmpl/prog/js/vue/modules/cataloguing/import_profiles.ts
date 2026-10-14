import { createApp, nextTick } from "vue";
import { createPinia } from "pinia";
import { createWebHistory, createRouter } from "vue-router";

import { config, library } from "@fortawesome/fontawesome-svg-core";
config.autoAddCss = false;
import "@fortawesome/fontawesome-svg-core/styles.css";
import {
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faCopy,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import vSelect from "vue-select";
import { useNavigationStore } from "../../stores/navigation";
import { useMainStore } from "../../stores/main";
import routesDef from "../../routes/cataloguing/import_profiles";

library.add(faPlus, faMinus, faPencil, faTrash, faSpinner, faCopy);

const pinia = createPinia();
const navigationStore = useNavigationStore(pinia);
const mainStore = useMainStore(pinia);
const { removeMessages } = mainStore;
const { setRoutes } = navigationStore;
const routes = setRoutes(routesDef);

const router = createRouter({
    history: createWebHistory(),
    linkExactActiveClass: "current",
    routes,
});

import App from "../../components/Cataloguing/ImportProfiles/Main.vue";

import "../../../../css/vue.css";

import i18n from "@koha-vue/i18n";

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
app.mount("#import-profiles");

router.isReady().then(() => {
    nextTick(() => {
        document.dispatchEvent(
            new CustomEvent("koha:vue-loaded", {
                detail: { module: "cataloguing/import_profiles" },
            })
        );
    });
});

router.beforeEach(to => {
    navigationStore.$patch({ current: to.matched, params: to.params || {} });
    removeMessages(); // This will actually flag the messages as displayed already
});
