import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";

import { library } from "@fortawesome/fontawesome-svg-core";
import {
    faList,
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faGlobe,
    faUpload,
    faDownload,
    faBuildingColumns,
    faCheck,
    faXmark,
    faRepeat,
    faBox,
    faCalendarDays,
    faBan,
    faCog,
    faEllipsisVertical,
    faArrowRight,
    faArrowLeft,
    faArrowUp,
    faArrowDown,
    faSearch,
} from "@fortawesome/free-solid-svg-icons";
import { FontAwesomeIcon } from "@fortawesome/vue-fontawesome";
import vSelect from "vue-select";

library.add(
    faList,
    faPlus,
    faMinus,
    faPencil,
    faTrash,
    faSpinner,
    faGlobe,
    faUpload,
    faDownload,
    faBuildingColumns,
    faCheck,
    faXmark,
    faRepeat,
    faBox,
    faCalendarDays,
    faBan,
    faCog,
    faEllipsisVertical,
    faArrowRight,
    faArrowLeft,
    faArrowUp,
    faArrowDown,
    faSearch
);

import App from "../components/ILL/Main.vue";

import { routes as routesDef } from "../routes/ill";

import { useMainStore } from "../stores/main";
import { useVendorStore } from "../stores/vendors";
import { useILLStore } from "../stores/ill";
import { useNavigationStore } from "../stores/navigation";
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
app.provide("vendorStore", useVendorStore(pinia));
app.provide("mainStore", mainStore);
app.provide("navigationStore", navigationStore);
const ILLStore = useILLStore(pinia);
app.provide("ILLStore", ILLStore);

const { removeMessages } = mainStore;
router.beforeEach((to, from) => {
    navigationStore.$patch({
        current: to.matched,
        params: to.params || {},
        from,
    });
    removeMessages();
});

router.isReady().then(() => {
    app.mount("#ill");
});
