<template>
    <div>
        <ResourceList
            v-if="routeAction === 'list'"
            :instancedResource="instancedResource"
            :key="instancedResource.refreshTemplate"
            @select-resource="$emit('select-resource', $event)"
        >
            <template #toolbar="{ resource, componentPropData }">
                <Toolbar
                    v-if="!instancedResource.embedded"
                    :toolbarButtons="instancedResource.toolbarButtons"
                    component="list"
                    :resource="resource"
                    :componentPropData="componentPropData"
                />
            </template>
            <template #filters="{ table }">
                <ResourceListFilters
                    v-if="instancedResource.table.addAdditionalFilters"
                    :instancedResource="instancedResource"
                    :table="table"
                />
            </template>
            <template
                v-if="slotComponents.header"
                #header="{ headerInformation }"
            >
                <component
                    :is="requiredSlotComponent('header')"
                    v-bind="headerInformation"
                ></component>
            </template>
        </ResourceList>
        <ResourceShow
            v-if="routeAction === 'show'"
            :instancedResource="instancedResource"
            :key="instancedResource.refreshTemplate"
        >
            <template #toolbar="{ resource, componentPropData }">
                <Toolbar
                    :toolbarButtons="instancedResource.toolbarButtons"
                    component="show"
                    :resource="resource"
                    :componentPropData="componentPropData"
                />
            </template>
        </ResourceShow>
        <ResourceFormSave
            v-if="['add', 'edit'].includes(routeAction)"
            :instancedResource="instancedResource"
            :key="instancedResource.refreshTemplate"
        >
            <template #toolbar="{ resource, componentPropData }">
                <Toolbar
                    :toolbarButtons="instancedResource.toolbarButtons"
                    component="form"
                    :resource="resource"
                    :componentPropData="componentPropData"
                    :sticky="
                        instancedResource.stickyToolbar &&
                        instancedResource.stickyToolbar.includes('Form')
                    "
                />
            </template>
        </ResourceFormSave>
    </div>
</template>

<script>
import ResourceListFilters from "./ResourceListFilters.vue";
import ResourceShow from "./ResourceShow.vue";
import ResourceFormSave from "./ResourceFormSave.vue";
import ResourceList from "./ResourceList.vue";
import Toolbar from "./Toolbar.vue";
import { loadComponent } from "@koha-vue/loaders/componentResolver";
import { defineAsyncComponent } from "vue";

export default {
    props: {
        routeAction: String,
        instancedResource: Object,
    },
    components: {
        ResourceListFilters,
        ResourceShow,
        ResourceFormSave,
        ResourceList,
        Toolbar,
    },
    setup(props) {
        const slotComponents = props.instancedResource.additionalSlotComponents(
            props.routeAction
        );
        const requiredSlotComponent = slot => {
            const importPath = slotComponents[slot];
            return defineAsyncComponent(loadComponent(importPath));
        };
        return {
            ...(typeof logged_in_user !== "undefined" && { logged_in_user }),
            slotComponents,
            requiredSlotComponent,
        };
    },
    name: "BaseResource",
};
</script>

<style>
fieldset.rows ol table {
    display: table;
    font-size: 100%;
}
</style>
