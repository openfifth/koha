import { createApp } from "vue";
import { createWebHistory, createRouter } from "vue-router";
import { createPinia } from "pinia";

import App from "../components/Plugin-store/Main.vue";

import { routes as routesDef } from "../routes/plugin-store";

import { useMainStore } from "../stores/main";
import { useNavigationStore } from "../stores/navigation";
import { usePluginStoreStore } from "../stores/plugin-store";
import i18n from "../i18n";

const pinia = createPinia();

const mainStore = useMainStore(pinia);
const navigationStore = useNavigationStore(pinia);
const pluginStoreStore = usePluginStoreStore(pinia);
const routes = navigationStore.setRoutes(routesDef);

const router = createRouter({
    history: createWebHistory(),
    linkExactActiveClass: "current",
    routes,
});

const app = createApp(App);

const rootComponent = app.use(i18n).use(pinia).use(router);

app.provide("mainStore", mainStore);
app.provide("navigationStore", navigationStore);
app.provide("pluginStoreStore", pluginStoreStore);

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
    app.mount("#plugin-store");
});
