<template>
    <div id="sub-header">
        <Breadcrumbs />
        <Help />
    </div>
    <div class="main container-fluid">
        <div class="row">
            <div class="col-md-10 order-md-2 order-sm-1">
                <main>
                    <Dialog />
                    <router-view />
                </main>
            </div>

            <div class="col-md-2 order-sm-2 order-md-1">
                <LeftMenu :title="$__('Plugins')"></LeftMenu>
            </div>
        </div>
    </div>
</template>

<script>
import Breadcrumbs from "../Breadcrumbs.vue";
import Help from "../Help.vue";
import LeftMenu from "../LeftMenu.vue";
import Dialog from "../Dialog.vue";

export default {
    components: {
        Breadcrumbs,
        Help,
        Dialog,
        LeftMenu,
    },
};
</script>
